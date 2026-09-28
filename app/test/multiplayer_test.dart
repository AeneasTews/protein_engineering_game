// Unit tests for the multiplayer client, plus an end-to-end match played through the real
// repositories and blocs against a running backend. The live test is skipped unless
// MUTATEIT_TEST_SERVER points at a backend started with short match settings, e.g.:
//
//   MUTATEIT_MATCH_TURNS=2 MUTATEIT_COUNTDOWN_S=0.5 MUTATEIT_DISABLE_BEACON=1 \
//     uv run uvicorn main:app --port 8125            (in backend/)
//   MUTATEIT_TEST_SERVER=http://localhost:8125 fvm flutter test test/multiplayer_test.dart
import "dart:io";

import "package:app/blocs/connect/connect_bloc.dart";
import "package:app/blocs/experiment/experiment_bloc.dart";
import "package:app/blocs/lobby/lobby_bloc.dart";
import "package:app/blocs/match/match_bloc.dart";
import "package:app/data/models/match_models.dart";
import "package:app/data/models/protein.dart";
import "package:app/data/repositories/match_repository.dart";
import "package:app/data/repositories/session_repository.dart";
import "package:flutter_test/flutter_test.dart";

MatchInfo _matchInfo({required DateTime startsAt, required DateTime endsAt}) => MatchInfo(
  matchId: 1,
  sessionId: 1,
  protein: const Protein(pdbId: "1E0L", name: "TEST", wildtypeSequence: "AAAA"),
  maxTurns: 5,
  startsAt: startsAt,
  endsAt: endsAt,
  clockOffset: Duration.zero,
  resume: false,
  ownHistory: const [],
  opponent: const PlayerProgress(playerId: "b", nickname: "bob", turnCount: 0, bestScore: null),
  opponentConnected: true,
);

Future<S> _waitFor<S>(Stream<S> stream, S current, bool Function(S) predicate) async {
  if (predicate(current)) return current;
  return stream.firstWhere(predicate).timeout(const Duration(seconds: 10));
}

/// Plays every turn of [match] through a MatchBloc and ExperimentBloc, as the game screen would.
Future<(MatchBloc, ExperimentBloc)> _playMatch(String server, MatchRepository repo, MatchInfo match) async {
  final matchBloc = MatchBloc(match: match, matchRepository: repo);
  final experiment = ExperimentBloc(sessionRepository: SessionRepository(baseUrl: server))
    ..add(
      ExperimentStart(
        sessionId: match.sessionId,
        protein: match.protein,
        maxTurns: match.maxTurns,
        // Read at use time, like the app does: it changes if the server restarted.
        playerToken: repo.identity!.token,
        lockReason: "Get ready…",
      ),
    );
  await _waitFor(matchBloc.stream, matchBloc.state, (s) => s.phase == MatchPhase.running);
  experiment.add(const ExperimentLockChanged(null));

  final wildtype = match.protein.wildtypeSequence;
  for (var position = 1; position <= match.maxTurns; position++) {
    final aminoAcid = wildtype[position - 1] == "A" ? "G" : "A";
    experiment.add(MutationChange(position: position, aminoAcid: aminoAcid));
    experiment.add(const Evaluate());
    await _waitFor(
      experiment.stream,
      experiment.state,
      (s) => s is ExperimentActive && !s.isEvaluating && s.turnCount == position,
    );
  }
  return (matchBloc, experiment);
}

/// A challenges B through the lobbies; returns both players' MatchInfo.
Future<(MatchInfo, MatchInfo)> _startMatch(LobbyBloc lobbyA, LobbyBloc lobbyB, MatchRepository repoB) async {
  final idB = repoB.identity!;
  await _waitFor(lobbyA.stream, lobbyA.state, (s) => s.players.any((p) => p.playerId == idB.playerId));
  lobbyA.add(LobbyChallengeRequested(playerId: idB.playerId));
  final withChallenge = await _waitFor(lobbyB.stream, lobbyB.state, (s) => s.incoming.isNotEmpty);
  lobbyB.add(LobbyChallengeAnswered(challengeId: withChallenge.incoming.single.challengeId, accept: true));
  final matchA = (await _waitFor(lobbyA.stream, lobbyA.state, (s) => s.pendingMatch != null)).pendingMatch!;
  final matchB = (await _waitFor(lobbyB.stream, lobbyB.state, (s) => s.pendingMatch != null)).pendingMatch!;
  return (matchA, matchB);
}

void main() {
  group("normalizeServerAddress", () {
    test("adds scheme and default port", () {
      expect(normalizeServerAddress("192.168.1.20"), "http://192.168.1.20:8000");
      expect(normalizeServerAddress(" 192.168.1.20:9000 "), "http://192.168.1.20:9000");
      expect(normalizeServerAddress("http://host:8000/"), "http://host:8000");
    });

    test("rejects empty input", () {
      expect(normalizeServerAddress("   "), isNull);
    });
  });

  group("MatchState.atTime", () {
    final start = DateTime(2026, 1, 1, 12);
    final state = MatchState.initial(_matchInfo(startsAt: start, endsAt: start.add(const Duration(minutes: 4))));

    test("counts down before the start", () {
      final s = state.atTime(start.subtract(const Duration(seconds: 2)));
      expect(s.phase, MatchPhase.countdown);
      expect(s.remaining, const Duration(seconds: 2));
    });

    test("runs until the end and clamps at zero", () {
      expect(state.atTime(start.add(const Duration(minutes: 1))).remaining, const Duration(minutes: 3));
      final late = state.atTime(start.add(const Duration(minutes: 5)));
      expect(late.phase, MatchPhase.running);
      expect(late.remaining, Duration.zero);
    });
  });

  final server = Platform.environment["MUTATEIT_TEST_SERVER"];
  test(
    "two clients play a full match through the blocs",
    skip: server == null ? "set MUTATEIT_TEST_SERVER to run against a live backend" : false,
    () async {
      final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
      final repoA = MatchRepository(baseUrl: server!);
      final repoB = MatchRepository(baseUrl: server);
      await repoA.register("alice$stamp");
      await repoB.register("bob$stamp");
      await repoA.connect();
      await repoB.connect();

      // Created after connecting: the server's greeting must not be lost before they subscribe.
      final lobbyA = LobbyBloc(matchRepository: repoA)..add(const LobbyStarted());
      final lobbyB = LobbyBloc(matchRepository: repoB)..add(const LobbyStarted());

      final (matchA, matchB) = await _startMatch(lobbyA, lobbyB, repoB);
      expect(matchA.matchId, matchB.matchId);
      expect(matchA.protein.pdbId, matchB.protein.pdbId);

      final results = await Future.wait([_playMatch(server, repoA, matchA), _playMatch(server, repoB, matchB)]);
      final (matchBlocA, experimentA) = results[0];
      final (matchBlocB, experimentB) = results[1];

      // Out of turns locks the experiment instead of finishing it.
      expect((experimentA.state as ExperimentActive).turnCount, matchA.maxTurns);

      final endA = await _waitFor(matchBlocA.stream, matchBlocA.state, (s) => s.phase == MatchPhase.finished);
      final endB = await _waitFor(matchBlocB.stream, matchBlocB.state, (s) => s.phase == MatchPhase.finished);
      expect(endA.result!.reason, MatchEndReason.turnsExhausted);
      expect(endA.result!.you.history.length, matchA.maxTurns);
      expect(endB.opponent.turnCount, matchA.maxTurns);
      if (endA.result!.outcome != MatchOutcome.draw) {
        expect(endA.result!.outcome == MatchOutcome.won, endB.result!.outcome == MatchOutcome.lost);
      }

      final lobbyAfter = await _waitFor(lobbyA.stream, lobbyA.state, (s) => s.activeMatchId == null);
      expect(lobbyAfter.activeMatchId, isNull);

      for (final bloc in [lobbyA, lobbyB, matchBlocA, matchBlocB, experimentA, experimentB]) {
        await bloc.close();
      }
      await repoA.dispose();
      await repoB.dispose();
    },
  );

  // Starts, kills and restarts its own backend, so it needs the backend directory (with its .venv).
  final backendDir = Platform.environment["MUTATEIT_TEST_BACKEND_DIR"];
  test(
    "clients re-register after the server restarts and can play again",
    skip: backendDir == null ? "set MUTATEIT_TEST_BACKEND_DIR to the backend directory" : false,
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      const port = 8127;
      const baseUrl = "http://localhost:$port";
      final dbPath = "${Directory.systemTemp.createTempSync("mutateit-restart-").path}/test.sqlite3";

      Future<Process> startServer() async {
        final process = await Process.start(
          "$backendDir/.venv/bin/uvicorn",
          ["main:app", "--port", "$port", "--no-access-log"],
          workingDirectory: backendDir,
          environment: {
            "DB_PATH": dbPath,
            "MUTATEIT_DISABLE_BEACON": "1",
            "MUTATEIT_MATCH_TURNS": "1",
            "MUTATEIT_COUNTDOWN_S": "0.2",
          },
        );
        final client = HttpClient();
        for (var attempt = 0; attempt < 80; attempt++) {
          try {
            final response = await (await client.getUrl(Uri.parse("$baseUrl/proteins"))).close();
            await response.drain<void>();
            if (response.statusCode == 200) break;
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
        client.close();
        return process;
      }

      var serverProcess = await startServer();
      try {
        final repoA = MatchRepository(baseUrl: baseUrl);
        final repoB = MatchRepository(baseUrl: baseUrl);
        await repoA.register("ann");
        await repoB.register("ben");
        await repoA.connect();
        await repoB.connect();
        final lobbyA = LobbyBloc(matchRepository: repoA)..add(const LobbyStarted());
        final lobbyB = LobbyBloc(matchRepository: repoB)..add(const LobbyStarted());
        await _waitFor(lobbyA.stream, lobbyA.state, (s) => s.players.isNotEmpty);
        final oldToken = repoA.identity!.token;

        serverProcess.kill();
        await serverProcess.exitCode;
        await _waitFor(lobbyA.stream, lobbyA.state, (s) => !s.connected);

        serverProcess = await startServer();
        await _waitFor(lobbyA.stream, lobbyA.state, (s) => s.connected);
        await _waitFor(lobbyB.stream, lobbyB.state, (s) => s.connected);
        expect(repoA.identity!.token, isNot(oldToken));

        // The lobby must filter out the *new* own id, and a match must be playable with the new token.
        final lobby = await _waitFor(
          lobbyA.stream,
          lobbyA.state,
          (s) => s.players.any((p) => p.playerId == repoB.identity!.playerId),
        );
        expect(lobby.players.any((p) => p.playerId == repoA.identity!.playerId), isFalse);

        final (matchA, matchB) = await _startMatch(lobbyA, lobbyB, repoB);
        final results = await Future.wait([_playMatch(baseUrl, repoA, matchA), _playMatch(baseUrl, repoB, matchB)]);
        final endA = await _waitFor(results[0].$1.stream, results[0].$1.state, (s) => s.phase == MatchPhase.finished);
        expect(endA.result!.you.history.length, 1);

        for (final bloc in [lobbyA, lobbyB, results[0].$1, results[0].$2, results[1].$1, results[1].$2]) {
          await bloc.close();
        }
        await repoA.dispose();
        await repoB.dispose();
      } finally {
        serverProcess.kill();
        await serverProcess.exitCode;
      }
    },
  );
}
