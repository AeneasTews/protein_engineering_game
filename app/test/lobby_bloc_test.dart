import "dart:async";

import "package:app/blocs/lobby/lobby_bloc.dart";
import "package:app/data/models/match_models.dart";
import "package:app/data/repositories/match_repository.dart";
import "package:flutter_test/flutter_test.dart";

/// Feeds server messages by hand and answers each leaderboard request only when told to.
class _FakeMatchRepository extends MatchRepository {
  _FakeMatchRepository() : super(baseUrl: "http://unused");

  final server = StreamController<ServerMessage>.broadcast();
  final leaderboardRequests = <Completer<List<LeaderboardEntry>>>[];

  @override
  Stream<ServerMessage> get messages => server.stream;

  @override
  PlayerIdentity? get identity => const PlayerIdentity(playerId: "me", nickname: "me", token: "token");

  @override
  bool get isConnected => true;

  @override
  Future<List<LeaderboardEntry>> getLeaderboard() {
    final request = Completer<List<LeaderboardEntry>>();
    leaderboardRequests.add(request);
    return request.future;
  }
}

const _noResult = MatchPlayerResult(
  progress: PlayerProgress(playerId: "x", nickname: "x", turnCount: 0, bestScore: null),
  bestMutant: null,
  history: [],
);

LobbyUpdated _lobby({required bool botInMatch}) => LobbyUpdated([
  const LobbyPlayer(playerId: "me", nickname: "me", inMatch: false),
  LobbyPlayer(playerId: "bot", nickname: "Bot", inMatch: botInMatch),
]);

Future<LobbyState> _until(LobbyBloc bloc, bool Function(LobbyState) predicate) async =>
    predicate(bloc.state) ? bloc.state : bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 2));

void main() {
  test("a slow leaderboard refresh after a match does not bring back stale player statuses", () async {
    final repository = _FakeMatchRepository();
    final lobby = LobbyBloc(matchRepository: repository)..add(const LobbyStarted());
    await Future<void>.delayed(Duration.zero);
    repository.leaderboardRequests.single.complete([]);

    repository.server.add(_lobby(botInMatch: true));
    await _until(lobby, (s) => s.players.length == 1 && s.players.single.inMatch);

    // The match ends: the lobby refreshes the leaderboard, and while that request is in
    // flight the server reports the bot as idle again.
    repository.server.add(
      const MatchEnded(
        MatchResult(
          matchId: 1,
          reason: MatchEndReason.turnsExhausted,
          outcome: MatchOutcome.draw,
          you: _noResult,
          opponent: _noResult,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.leaderboardRequests, hasLength(2));
    repository.server.add(_lobby(botInMatch: false));
    await _until(lobby, (s) => !s.players.single.inMatch);

    repository.leaderboardRequests.last.complete([
      const LeaderboardEntry(nickname: "me", wins: 1, losses: 0, draws: 0),
    ]);
    final after = await _until(lobby, (s) => s.leaderboard.isNotEmpty);
    expect(after.players.single.inMatch, isFalse);

    await lobby.close();
    await repository.server.close();
  });
}
