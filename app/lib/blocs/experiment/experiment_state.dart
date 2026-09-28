part of "experiment_bloc.dart";

sealed class ExperimentState extends Equatable {
  const ExperimentState();

  @override
  List<Object?> get props => [];
}

final class ExperimentInitial extends ExperimentState {
  const ExperimentInitial();
}

final class ExperimentActive extends ExperimentState {
  final int sessionId;
  final Protein protein;
  final List<(int pos, String aa)> currentMutations;
  final List<ExperimentEntry> history;
  final double lastScore;
  final int turnCount;
  final int maxTurns;
  final bool isEvaluating;
  final String? lockReason;

  const ExperimentActive({
    required this.sessionId,
    required this.protein,
    required this.currentMutations,
    required this.history,
    required this.lastScore,
    required this.turnCount,
    required this.maxTurns,
    required this.isEvaluating,
    this.lockReason,
  });

  bool get isLocked => lockReason != null;

  ExperimentActive copyWith({
    List<(int pos, String aa)>? currentMutations,
    List<ExperimentEntry>? history,
    double? lastScore,
    int? turnCount,
    bool? isEvaluating,
  }) => ExperimentActive(
    sessionId: sessionId,
    protein: protein,
    currentMutations: currentMutations ?? this.currentMutations,
    history: history ?? this.history,
    lastScore: lastScore ?? this.lastScore,
    turnCount: turnCount ?? this.turnCount,
    maxTurns: maxTurns,
    isEvaluating: isEvaluating ?? this.isEvaluating,
    lockReason: lockReason,
  );

  // Separate from copyWith because null is a meaningful value (unlocked).
  ExperimentActive withLock(String? lockReason) => ExperimentActive(
    sessionId: sessionId,
    protein: protein,
    currentMutations: currentMutations,
    history: history,
    lastScore: lastScore,
    turnCount: turnCount,
    maxTurns: maxTurns,
    isEvaluating: isEvaluating,
    lockReason: lockReason,
  );

  @override
  List<Object?> get props => [
    sessionId,
    protein,
    currentMutations,
    history,
    lastScore,
    turnCount,
    maxTurns,
    isEvaluating,
    lockReason,
  ];
}

final class ExperimentFinished extends ExperimentState {
  final List<ExperimentEntry> history;
  final double bestScore;

  const ExperimentFinished({required this.history, required this.bestScore});

  @override
  List<Object?> get props => [history, bestScore];
}
