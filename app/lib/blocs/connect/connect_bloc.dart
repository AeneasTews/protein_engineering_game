import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../config.dart";
import "../../constants.dart";
import "../../data/api_exception.dart";
import "../../data/models/match_models.dart";
import "../../data/repositories/match_repository.dart";
import "../../data/services/lan_discovery.dart";

part "connect_event.dart";
part "connect_state.dart";

/// A live, registered connection to a multiplayer server.
class ServerConnection {
  final String baseUrl;
  final PlayerIdentity identity;
  final MatchRepository matchRepository;

  const ServerConnection({required this.baseUrl, required this.identity, required this.matchRepository});
}

class ConnectBloc extends Bloc<ConnectEvent, ConnectState> {
  static const _addressKey = "server_address";
  static const _nicknameKey = "nickname";

  final LanDiscovery _discovery;

  ConnectBloc({required LanDiscovery discovery}) : _discovery = discovery, super(const ConnectState()) {
    on<ConnectStarted>(_onStarted);
    on<ConnectRequested>(_onConnectRequested);
  }

  Future<void> _onStarted(ConnectStarted event, Emitter<ConnectState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      emit(
        state.copyWith(
          savedAddress: prefs.getString(_addressKey) ?? Config.apiBaseUrl,
          savedNickname: prefs.getString(_nicknameKey) ?? "",
          preferencesLoaded: true,
        ),
      );
    } catch (_) {
      emit(state.copyWith(savedAddress: Config.apiBaseUrl, preferencesLoaded: true));
    }

    await emit.forEach<DiscoveredServer>(
      _discovery.discover(),
      onData: (server) =>
          state.discovered.contains(server) ? state : state.copyWith(discovered: [...state.discovered, server]),
      onError: (_, _) => state,
    );
  }

  Future<void> _onConnectRequested(ConnectRequested event, Emitter<ConnectState> emit) async {
    if (state.status == ConnectStatus.connecting) return;
    final nickname = event.nickname.trim();
    if (nickname.isEmpty) {
      emit(state.copyWith(status: ConnectStatus.error, error: "Enter a nickname"));
      return;
    }
    final baseUrl = normalizeServerAddress(event.address);
    if (baseUrl == null) {
      emit(state.copyWith(status: ConnectStatus.error, error: "Enter the server address, e.g. 192.168.1.20"));
      return;
    }

    emit(state.copyWith(status: ConnectStatus.connecting));
    final repository = MatchRepository(baseUrl: baseUrl);
    try {
      final identity = await repository.register(nickname).timeout(Network.connectTimeout);
      await repository.connect();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_addressKey, event.address.trim());
        await prefs.setString(_nicknameKey, nickname);
      } catch (_) {
        // Remembering the last server is a convenience only.
      }
      emit(
        state.copyWith(
          status: ConnectStatus.connected,
          connection: ServerConnection(baseUrl: baseUrl, identity: identity, matchRepository: repository),
        ),
      );
    } on ApiException catch (e) {
      await repository.dispose();
      final error = e.statusCode == 409 ? "\"$nickname\" is already online — pick another nickname" : _body(e);
      emit(state.copyWith(status: ConnectStatus.error, error: error));
    } catch (_) {
      await repository.dispose();
      emit(state.copyWith(status: ConnectStatus.error, error: "Could not reach a MutateIt server at $baseUrl"));
    }
  }

  String _body(ApiException e) => "Server rejected the request (${e.statusCode}): ${e.body}";
}

/// Accepts "host", "host:port" or a full URL and returns the HTTP base URL, or null if empty.
String? normalizeServerAddress(String input) {
  var address = input.trim();
  if (address.isEmpty) return null;
  if (!address.contains("://")) address = "http://$address";
  final uri = Uri.tryParse(address);
  if (uri == null || uri.host.isEmpty) return null;
  final port = uri.hasPort ? uri.port : Network.defaultServerPort;
  final path = uri.path.endsWith("/") ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  return "${uri.scheme}://${uri.host}:$port$path";
}
