import "package:equatable/equatable.dart";
import "protein.dart";
import "trajectory_step.dart";

// Times sent by the server are Unix epoch seconds (as doubles).
DateTime _fromEpochSeconds(num seconds) => DateTime.fromMicrosecondsSinceEpoch((seconds * 1e6).round());

class PlayerIdentity extends Equatable {
  final String playerId;
  final String nickname;
  final String token;

  const PlayerIdentity({required this.playerId, required this.nickname, required this.token});

  factory PlayerIdentity.fromJson(Map<String, dynamic> json) => PlayerIdentity(
    playerId: json["player_id"] as String,
    nickname: json["nickname"] as String,
    token: json["token"] as String,
  );

  @override
  List<Object?> get props => [playerId, nickname, token];
}

class LobbyPlayer extends Equatable {
  final String playerId;
  final String nickname;
  final bool inMatch;

  const LobbyPlayer({required this.playerId, required this.nickname, required this.inMatch});

  factory LobbyPlayer.fromJson(Map<String, dynamic> json) => LobbyPlayer(
    playerId: json["player_id"] as String,
    nickname: json["nickname"] as String,
    inMatch: json["status"] == "in_match",
  );

  @override
  List<Object?> get props => [playerId, nickname, inMatch];
}

class Challenge extends Equatable {
  final String challengeId;
  final String playerId;
  final String nickname;
  final String? pdbId;
  final bool rematch;

  const Challenge({
    required this.challengeId,
    required this.playerId,
    required this.nickname,
    required this.pdbId,
    required this.rematch,
  });

  // `other` is the "from" object for received challenges and the "to" object for sent ones.
  factory Challenge.fromJson(Map<String, dynamic> json, Map<String, dynamic> other) => Challenge(
    challengeId: json["challenge_id"] as String,
    playerId: other["player_id"] as String,
    nickname: other["nickname"] as String,
    pdbId: json["pdb_id"] as String?,
    rematch: json["rematch"] as bool? ?? false,
  );

  @override
  List<Object?> get props => [challengeId, playerId, nickname, pdbId, rematch];
}

class PlayerProgress extends Equatable {
  final String playerId;
  final String nickname;
  final int turnCount;
  final double? bestScore;

  const PlayerProgress({
    required this.playerId,
    required this.nickname,
    required this.turnCount,
    required this.bestScore,
  });

  factory PlayerProgress.fromJson(Map<String, dynamic> json) => PlayerProgress(
    playerId: json["player_id"] as String,
    nickname: json["nickname"] as String,
    turnCount: json["turn_count"] as int,
    bestScore: (json["best_score"] as num?)?.toDouble(),
  );

  PlayerProgress copyWith({int? turnCount, double? bestScore}) => PlayerProgress(
    playerId: playerId,
    nickname: nickname,
    turnCount: turnCount ?? this.turnCount,
    bestScore: bestScore ?? this.bestScore,
  );

  @override
  List<Object?> get props => [playerId, nickname, turnCount, bestScore];
}

class MatchInfo extends Equatable {
  final int matchId;
  final int sessionId;
  final Protein protein;
  final int maxTurns;
  final DateTime startsAt;
  final DateTime endsAt;
  // serverNow - localNow when the message arrived; add it to the local clock to get server time.
  final Duration clockOffset;
  final bool resume;
  final List<TrajectoryStep> ownHistory;
  final PlayerProgress opponent;
  final bool opponentConnected;

  const MatchInfo({
    required this.matchId,
    required this.sessionId,
    required this.protein,
    required this.maxTurns,
    required this.startsAt,
    required this.endsAt,
    required this.clockOffset,
    required this.resume,
    required this.ownHistory,
    required this.opponent,
    required this.opponentConnected,
  });

  factory MatchInfo.fromJson(Map<String, dynamic> json) {
    final you = json["you"] as Map<String, dynamic>;
    final opponent = json["opponent"] as Map<String, dynamic>;
    return MatchInfo(
      matchId: json["match_id"] as int,
      sessionId: json["session_id"] as int,
      protein: Protein.fromJson(json["protein"] as Map<String, dynamic>),
      maxTurns: json["max_turns"] as int,
      startsAt: _fromEpochSeconds(json["starts_at"] as num),
      endsAt: _fromEpochSeconds(json["ends_at"] as num),
      clockOffset: _fromEpochSeconds(json["server_now"] as num).difference(DateTime.now()),
      resume: json["resume"] as bool? ?? false,
      ownHistory: (you["history"] as List<dynamic>)
          .map((e) => TrajectoryStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      opponent: PlayerProgress.fromJson(opponent),
      opponentConnected: opponent["connected"] as bool? ?? true,
    );
  }

  DateTime serverNow() => DateTime.now().add(clockOffset);

  @override
  List<Object?> get props => [matchId, sessionId, protein.pdbId, maxTurns, startsAt, endsAt, resume];
}

class MatchPlayerResult extends Equatable {
  final PlayerProgress progress;
  final String? bestMutant;
  final List<TrajectoryStep> history;

  const MatchPlayerResult({required this.progress, required this.bestMutant, required this.history});

  factory MatchPlayerResult.fromJson(Map<String, dynamic> json) => MatchPlayerResult(
    progress: PlayerProgress.fromJson(json),
    bestMutant: json["best_mutant"] as String?,
    history: (json["history"] as List<dynamic>).map((e) => TrajectoryStep.fromJson(e as Map<String, dynamic>)).toList(),
  );

  @override
  List<Object?> get props => [progress, bestMutant, history.length];
}

enum MatchEndReason {
  timeUp("Time's up"),
  turnsExhausted("All turns used"),
  forfeit("Forfeit"),
  disconnect("Opponent left"),
  unknown("Match over");

  final String label;

  const MatchEndReason(this.label);

  static MatchEndReason fromJson(String? value) => switch (value) {
    "time_up" => timeUp,
    "turns_exhausted" => turnsExhausted,
    "forfeit" => forfeit,
    "disconnect" => disconnect,
    _ => unknown,
  };
}

enum MatchOutcome { won, lost, draw }

class MatchResult extends Equatable {
  final int matchId;
  final MatchEndReason reason;
  final MatchOutcome outcome;
  final MatchPlayerResult you;
  final MatchPlayerResult opponent;

  const MatchResult({
    required this.matchId,
    required this.reason,
    required this.outcome,
    required this.you,
    required this.opponent,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    final you = MatchPlayerResult.fromJson(json["you"] as Map<String, dynamic>);
    final winnerId = json["winner_id"] as String?;
    return MatchResult(
      matchId: json["match_id"] as int,
      reason: MatchEndReason.fromJson(json["reason"] as String?),
      outcome: winnerId == null
          ? MatchOutcome.draw
          : (winnerId == you.progress.playerId ? MatchOutcome.won : MatchOutcome.lost),
      you: you,
      opponent: MatchPlayerResult.fromJson(json["opponent"] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [matchId, reason, outcome, you, opponent];
}

class LeaderboardEntry extends Equatable {
  final String nickname;
  final int wins;
  final int losses;
  final int draws;

  const LeaderboardEntry({required this.nickname, required this.wins, required this.losses, required this.draws});

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    nickname: json["nickname"] as String,
    wins: json["wins"] as int,
    losses: json["losses"] as int,
    draws: json["draws"] as int,
  );

  @override
  List<Object?> get props => [nickname, wins, losses, draws];
}
