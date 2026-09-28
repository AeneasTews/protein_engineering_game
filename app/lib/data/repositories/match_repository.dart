import "dart:async";
import "dart:convert";
import "package:http/http.dart" as http;
import "package:web_socket_channel/web_socket_channel.dart";
import "../../constants.dart";
import "../api_exception.dart";
import "../models/match_models.dart";

// ---------------------------------------------------------------------------
// Messages pushed by the server over /ws
// ---------------------------------------------------------------------------

sealed class ServerMessage {
  const ServerMessage();
}

final class ConnectionChanged extends ServerMessage {
  final bool connected;
  const ConnectionChanged(this.connected);
}

final class LobbyUpdated extends ServerMessage {
  final List<LobbyPlayer> players;
  const LobbyUpdated(this.players);
}

final class ChallengeReceived extends ServerMessage {
  final Challenge challenge;
  const ChallengeReceived(this.challenge);
}

final class ChallengeSent extends ServerMessage {
  final Challenge challenge;
  const ChallengeSent(this.challenge);
}

final class ChallengeDeclined extends ServerMessage {
  final String challengeId;
  final String by;
  const ChallengeDeclined({required this.challengeId, required this.by});
}

final class ChallengeCancelled extends ServerMessage {
  final String challengeId;
  const ChallengeCancelled(this.challengeId);
}

final class MatchStarted extends ServerMessage {
  final MatchInfo match;
  const MatchStarted(this.match);
}

final class OpponentProgressed extends ServerMessage {
  final int turnCount;
  final double? bestScore;
  final bool newBest;
  const OpponentProgressed({required this.turnCount, required this.bestScore, required this.newBest});
}

final class OpponentConnectionChanged extends ServerMessage {
  final bool connected;
  const OpponentConnectionChanged(this.connected);
}

final class MatchEnded extends ServerMessage {
  final MatchResult result;
  const MatchEnded(this.result);
}

final class ServerError extends ServerMessage {
  final String message;
  const ServerError(this.message);
}

ServerMessage? _parseServerMessage(Map<String, dynamic> json) => switch (json["type"]) {
  "lobby" => LobbyUpdated(
    (json["players"] as List<dynamic>).map((p) => LobbyPlayer.fromJson(p as Map<String, dynamic>)).toList(),
  ),
  "challenge_received" => ChallengeReceived(Challenge.fromJson(json, json["from"] as Map<String, dynamic>)),
  "challenge_sent" => ChallengeSent(Challenge.fromJson(json, json["to"] as Map<String, dynamic>)),
  "challenge_declined" => ChallengeDeclined(challengeId: json["challenge_id"] as String, by: json["by"] as String),
  "challenge_cancelled" => ChallengeCancelled(json["challenge_id"] as String),
  "match_start" => MatchStarted(MatchInfo.fromJson(json)),
  "opponent_progress" => OpponentProgressed(
    turnCount: json["turn_count"] as int,
    bestScore: (json["best_score"] as num?)?.toDouble(),
    newBest: json["new_best"] as bool,
  ),
  "opponent_status" => OpponentConnectionChanged(json["connected"] as bool),
  "match_end" => MatchEnded(MatchResult.fromJson(json)),
  "error" => ServerError(json["message"] as String),
  _ => null, // welcome, pong and future message types
};

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Owns the player's connection to a multiplayer server: registration over REST, then a
/// WebSocket that reconnects on its own until [dispose] is called.
class MatchRepository {
  final String baseUrl;
  final http.Client _client;
  late final _messages = StreamController<ServerMessage>.broadcast(onListen: _flushBacklog);
  // The server greets a new connection straight away (lobby, pending challenges, a resumed match),
  // usually before anyone has subscribed, so messages are held until the first listener arrives.
  final List<ServerMessage> _backlog = [];

  PlayerIdentity? _identity;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connected = false;

  MatchRepository({required this.baseUrl}) : _client = http.Client();

  Stream<ServerMessage> get messages => _messages.stream;
  PlayerIdentity? get identity => _identity;
  bool get isConnected => _connected;

  Future<PlayerIdentity> register(String nickname) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/players"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"nickname": nickname}),
    );
    _assertOk(response);
    return _identity = PlayerIdentity.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final response = await _client.get(Uri.parse("$baseUrl/leaderboard"));
    _assertOk(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Opens the WebSocket. Completes once the server has accepted it; throws if it can't.
  Future<void> connect() async {
    final identity = _identity;
    if (identity == null) throw StateError("register() must be called before connect()");

    final channel = WebSocketChannel.connect(_wsUri(identity.token));
    await channel.ready.timeout(Network.connectTimeout);
    _attach(channel);
  }

  void challenge({required String playerId, String? pdbId}) =>
      _send({"type": "challenge", "to": playerId, "pdb_id": pdbId});

  void respondToChallenge({required String challengeId, required bool accept}) =>
      _send({"type": "challenge_response", "challenge_id": challengeId, "accept": accept});

  void cancelChallenge() => _send({"type": "cancel_challenge"});

  void rematch() => _send({"type": "rematch"});

  void forfeit() => _send({"type": "forfeit"});

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _messages.close();
    _client.close();
  }

  void _attach(WebSocketChannel channel) {
    _channel = channel;
    _setConnected(true);
    _subscription = channel.stream.listen(
      (data) {
        if (data is! String) return;
        final message = _parseServerMessage(jsonDecode(data) as Map<String, dynamic>);
        if (message != null) _emit(message);
      },
      onDone: _onSocketClosed,
      onError: (_) => _onSocketClosed(),
      cancelOnError: true,
    );
  }

  void _onSocketClosed() {
    _subscription = null;
    _channel = null;
    _setConnected(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Network.reconnectDelay, () async {
      if (_disposed) return;
      try {
        await connect();
      } catch (_) {
        // A restarted server has forgotten our token, so claim the nickname again.
        try {
          final nickname = _identity?.nickname;
          if (nickname != null) await register(nickname);
          await connect();
        } catch (_) {
          _scheduleReconnect();
        }
      }
    });
  }

  void _setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    _emit(ConnectionChanged(connected));
  }

  void _emit(ServerMessage message) {
    if (_messages.isClosed) return;
    if (_messages.hasListener) {
      _messages.add(message);
    } else {
      _backlog.add(message);
    }
  }

  void _flushBacklog() {
    final pending = List<ServerMessage>.of(_backlog);
    _backlog.clear();
    // Deliver after the new subscription is fully set up.
    scheduleMicrotask(() {
      for (final message in pending) {
        if (!_messages.isClosed) _messages.add(message);
      }
    });
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Uri _wsUri(String token) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == "https" ? "wss" : "ws",
      path: "${base.path}/ws",
      queryParameters: {"token": token},
    );
  }

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }
}
