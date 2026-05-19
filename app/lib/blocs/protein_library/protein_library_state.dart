part of "protein_library_bloc.dart";

sealed class ProteinLibraryState extends Equatable {
  const ProteinLibraryState();

  @override
  List<Object?> get props => [];
}

final class ProteinLibraryInitial extends ProteinLibraryState {
  const ProteinLibraryInitial();
}

final class ProteinLibraryLoading extends ProteinLibraryState {
  const ProteinLibraryLoading();
}

final class ProteinLibraryLoaded extends ProteinLibraryState {
  final List<Protein> proteins;
  final String? selectedPdbId;

  const ProteinLibraryLoaded({required this.proteins, this.selectedPdbId});

  ProteinLibraryLoaded copyWith({List<Protein>? proteins, String? selectedPdbId}) => ProteinLibraryLoaded(
    proteins: proteins ?? this.proteins,
    selectedPdbId: selectedPdbId ?? this.selectedPdbId,
  );

  @override
  List<Object?> get props => [proteins, selectedPdbId];
}

final class ProteinLibraryError extends ProteinLibraryState {
  final String message;

  const ProteinLibraryError(this.message);

  @override
  List<Object?> get props => [message];
}