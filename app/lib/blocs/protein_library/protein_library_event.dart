part of "protein_library_bloc.dart";

sealed class ProteinLibraryEvent extends Equatable {
  const ProteinLibraryEvent();

  @override
  List<Object?> get props => [];
}

final class ProteinLibraryStarted extends ProteinLibraryEvent {
  const ProteinLibraryStarted();
}

final class ProteinSelected extends ProteinLibraryEvent {
  final String pdbId;
  const ProteinSelected(this.pdbId);

  @override
  List<Object?> get props => [pdbId];
}