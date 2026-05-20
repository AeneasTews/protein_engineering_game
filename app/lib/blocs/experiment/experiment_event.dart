part of "experiment_bloc.dart";

sealed class ExperimentEvent extends Equatable {
  const ExperimentEvent();

  @override
  List<Object?> get props => [];
}

final class ExperimentStart extends ExperimentEvent {
  final int sessionId;
  final Protein protein;

  const ExperimentStart({required this.sessionId, required this.protein});

  @override
  List<Object?> get props => [sessionId, protein];
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