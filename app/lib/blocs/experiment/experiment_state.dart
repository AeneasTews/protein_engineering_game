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
  final bool isEvaluating;

  const ExperimentActive({
    required this.sessionId,
    required this.protein,
    required this.currentMutations,
    required this.history,
    required this.lastScore,
    required this.turnCount,
    required this.isEvaluating
  });

  ExperimentActive copyWith({
    List<(int pos, String aa)>? currentMutations,
    List<ExperimentEntry>? history,
    double? lastScore,
    int? turnCount,
    bool? isEvaluating
  }) => ExperimentActive(
    sessionId: sessionId,
    protein: protein,
    currentMutations: currentMutations ?? this.currentMutations,
    history: history ?? this.history,
    lastScore: lastScore ?? this.lastScore,
    turnCount: turnCount ?? this.turnCount,
    isEvaluating: isEvaluating ?? this.isEvaluating
  );

  @override
  List<Object?> get props => [
    sessionId,
    protein,
    currentMutations,
    history,
    lastScore,
    turnCount,
    isEvaluating
  ];
}

final class ExperimentFinished extends ExperimentState {
  final List<ExperimentEntry> history;
  final double bestScore;
  final Highscore highscore;

  const ExperimentFinished({required this.history, required this.bestScore, required this.highscore});

  @override
  List<Object?> get props => [history, bestScore, highscore];
}