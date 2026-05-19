import "trajectory_step.dart";

class EvaluationResult {
  final int sessionId;
  final String pdbId;
  final String mutant;
  final double score;
  final int turnCount;
  final List<TrajectoryStep> history;

  const EvaluationResult({
    required this.sessionId,
    required this.pdbId,
    required this.mutant,
    required this.score,
    required this.turnCount,
    required this.history,
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> json) => EvaluationResult(
    sessionId: json["session_id"] as int,
    pdbId: json["pdb_id"] as String,
    mutant: json["mutant"] as String,
    score: (json["score"] as num).toDouble(),
    turnCount: json["turn_count"] as int,
    history: (json["history"] as List<dynamic>).map((e) => TrajectoryStep.fromJson(e as Map<String, dynamic>)).toList(),
  );
}