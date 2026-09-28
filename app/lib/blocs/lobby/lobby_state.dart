part of "lobby_bloc.dart";

final class LobbyState extends Equatable {
  final bool connected;
  // Other online players; the local player is filtered out.
  final List<LobbyPlayer> players;
  final List<Challenge> incoming;
  final Challenge? outgoing;
  final List<LeaderboardEntry> leaderboard;
  final int? activeMatchId;
  // A match that has started but that the lobby screen hasn't opened yet.
  final MatchInfo? pendingMatch;
  final String? notice;
  // Bumped with every notice so the same text twice still shows twice.
  final int noticeId;

  const LobbyState({
    this.connected = false,
    this.players = const [],
    this.incoming = const [],
    this.outgoing,
    this.leaderboard = const [],
    this.activeMatchId,
    this.pendingMatch,
    this.notice,
    this.noticeId = 0,
  });

  LobbyState copyWith({
    bool? connected,
    List<LobbyPlayer>? players,
    List<Challenge>? incoming,
    Challenge? outgoing,
    bool clearOutgoing = false,
    List<LeaderboardEntry>? leaderboard,
    int? activeMatchId,
    bool clearActiveMatch = false,
    MatchInfo? pendingMatch,
    bool clearPendingMatch = false,
  }) => LobbyState(
    connected: connected ?? this.connected,
    players: players ?? this.players,
    incoming: incoming ?? this.incoming,
    outgoing: clearOutgoing ? null : (outgoing ?? this.outgoing),
    leaderboard: leaderboard ?? this.leaderboard,
    activeMatchId: clearActiveMatch ? null : (activeMatchId ?? this.activeMatchId),
    pendingMatch: clearPendingMatch ? null : (pendingMatch ?? this.pendingMatch),
    notice: notice,
    noticeId: noticeId,
  );

  LobbyState withNotice(String notice) => LobbyState(
    connected: connected,
    players: players,
    incoming: incoming,
    outgoing: outgoing,
    leaderboard: leaderboard,
    activeMatchId: activeMatchId,
    pendingMatch: pendingMatch,
    notice: notice,
    noticeId: noticeId + 1,
  );

  @override
  List<Object?> get props => [
    connected,
    players,
    incoming,
    outgoing,
    leaderboard,
    activeMatchId,
    pendingMatch,
    notice,
    noticeId,
  ];
}
