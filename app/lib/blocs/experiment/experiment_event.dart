part of "experiment_bloc.dart";

sealed class ExperimentEvent extends Equatable {
  const ExperimentEvent();

  @override
  List<Object?> get props => [];
}

final class ExperimentStart extends ExperimentEvent {
  final int sessionId;
  final Protein protein;
  final int maxTurns;
  // Set for match sessions: evaluations need the player's token, and running out of turns
  // locks the experiment instead of finishing it (the match decides when it's over).
  final String? playerToken;
  final List<TrajectoryStep> initialHistory;
  final String? lockReason;

  const ExperimentStart({
    required this.sessionId,
    required this.protein,
    this.maxTurns = GameRules.maxTurns,
    this.playerToken,
    this.initialHistory = const [],
    this.lockReason,
  });

  bool get isMatch => playerToken != null;

  @override
  List<Object?> get props => [sessionId, protein, maxTurns, playerToken, initialHistory, lockReason];
}

final class ExperimentLockChanged extends ExperimentEvent {
  // null unlocks; otherwise the reason is shown on the submit button.
  final String? lockReason;

  const ExperimentLockChanged(this.lockReason);

  @override
  List<Object?> get props => [lockReason];
}

final class MutationChange extends ExperimentEvent {
  final int position;
  final String aminoAcid;

  const MutationChange({required this.position, required this.aminoAcid});

  @override
  List<Object?> get props => [position, aminoAcid];
}

final class MutationSetLoad extends ExperimentEvent {
  final List<(int pos, String aa)> mutations;

  const MutationSetLoad({required this.mutations});

  @override
  List<Object?> get props => [mutations];
}

final class Evaluate extends ExperimentEvent {
  const Evaluate();
}

final class ExperimentClose extends ExperimentEvent {
  const ExperimentClose();
}
