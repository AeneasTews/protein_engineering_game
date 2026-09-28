part of "connect_bloc.dart";

enum ConnectStatus { idle, connecting, connected, error }

final class ConnectState extends Equatable {
  final List<DiscoveredServer> discovered;
  final bool preferencesLoaded;
  final String savedAddress;
  final String savedNickname;
  final ConnectStatus status;
  final String? error;
  final ServerConnection? connection;

  const ConnectState({
    this.discovered = const [],
    this.preferencesLoaded = false,
    this.savedAddress = "",
    this.savedNickname = "",
    this.status = ConnectStatus.idle,
    this.error,
    this.connection,
  });

  ConnectState copyWith({
    List<DiscoveredServer>? discovered,
    bool? preferencesLoaded,
    String? savedAddress,
    String? savedNickname,
    ConnectStatus? status,
    String? error,
    ServerConnection? connection,
  }) => ConnectState(
    discovered: discovered ?? this.discovered,
    preferencesLoaded: preferencesLoaded ?? this.preferencesLoaded,
    savedAddress: savedAddress ?? this.savedAddress,
    savedNickname: savedNickname ?? this.savedNickname,
    status: status ?? this.status,
    // Errors only live as long as the status that produced them.
    error: (status ?? this.status) == ConnectStatus.error ? (error ?? this.error) : null,
    connection: connection ?? this.connection,
  );

  @override
  List<Object?> get props => [discovered, preferencesLoaded, savedAddress, savedNickname, status, error, connection];
}
