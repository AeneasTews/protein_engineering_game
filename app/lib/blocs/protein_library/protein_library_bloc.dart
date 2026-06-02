import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../../../data/models/protein.dart";
import "../../../data/repositories/protein_repository.dart";
import "../../../data/api_exception.dart";
import "../../../data/models/highscore.dart";

part "protein_library_event.dart";
part "protein_library_state.dart";

class ProteinLibraryBloc extends Bloc<ProteinLibraryEvent, ProteinLibraryState> {
  final ProteinRepository _proteinRepository;

  ProteinLibraryBloc({required ProteinRepository proteinRepository})
      : _proteinRepository = proteinRepository, super(const ProteinLibraryInitial()) {
    on<ProteinLibraryStarted>(_onStarted);
    on<ProteinSelected>(_onProteinSelected);
  }

  Future<void> _onStarted(ProteinLibraryStarted event, Emitter<ProteinLibraryState> emit) async {
    emit(const ProteinLibraryLoading());
    try {
      final proteins = await _proteinRepository.getProteins();
      final highscores = await _proteinRepository.getHighscores(proteins.map((p) => p.pdbId).toList());
      emit(ProteinLibraryLoaded(proteins: proteins, highscores: highscores));
    } on ApiException catch (e) {
      emit(ProteinLibraryError("Failed to load proteins: ${e.statusCode}"));
    } catch (e) {
      emit(ProteinLibraryError("Unexpected error: $e"));
    }
  }

  void _onProteinSelected(ProteinSelected event, Emitter<ProteinLibraryState> emit) {
    final current = state;
    if (current is! ProteinLibraryLoaded) return;
    emit(current.copyWith(selectedPdbId: event.pdbId));
  }
}