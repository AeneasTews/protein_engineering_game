part of "structure_bloc.dart";

sealed class StructureState extends Equatable {
  const StructureState();

  @override
  List<Object?> get props => [];
}

final class StructureInitial extends StructureState {
  const StructureInitial();
}

final class StructureReady extends StructureState {
  final int? selectedPosition;
  final List<(int pos, String aa)> highlightedMutations;

  const StructureReady({this.selectedPosition, required this.highlightedMutations});

  StructureReady copyWith({
    int? selectedPosition,
    List<(int pos, String aa)>? highlightedMutations,
    bool clearSelection = false,
  }) => StructureReady(
    selectedPosition: clearSelection ? null : selectedPosition ?? this.selectedPosition,
    highlightedMutations: highlightedMutations ?? this.highlightedMutations
  );

  @override
  List<Object?> get props => [selectedPosition, highlightedMutations];
}