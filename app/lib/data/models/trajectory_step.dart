class TrajectoryStep {
  final String mutant;
  final double score;
  final int turnCount;

  const TrajectoryStep({required this.mutant, required this.score, required this.turnCount});

  factory TrajectoryStep.fromJson(Map<String, dynamic> json) => TrajectoryStep(
    mutant: json["mutant"] as String,
    score: (json["score"] as num).toDouble(),
    turnCount: json["turn_count"] as int,
  );
}