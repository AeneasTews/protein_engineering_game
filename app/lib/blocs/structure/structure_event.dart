part of "structure_bloc.dart";

sealed class StructureEvent extends Equatable {
  const StructureEvent();

  @override
  List<Object?> get props => [];
}

final class StructureLoadRequested extends StructureEvent {
  final String pdbData;

  const StructureLoadRequested({required this.pdbData});

  @override
  List<Object?> get props => [pdbData];
}

final class ResidueSelected extends StructureEvent {
  final int position;

  const ResidueSelected({required this.position});

  @override
  List<Object?> get props => [position];
}

final class ViewStructure extends StructureEvent {
  const ViewStructure();
}

final class MutationsUpdated extends StructureEvent {
  final List<(int pos, String aa)> mutations;

  const MutationsUpdated({required this.mutations});

  @override
  List<Object?> get props => [mutations];
}