import 'package:app/data/api_exception.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/experiment_entry.dart';
import '../../data/models/highscore.dart';
import '../../data/models/protein.dart';
import "package:flutter_bloc/flutter_bloc.dart";
import '../../data/repositories/session_repository.dart';

part "experiment_event.dart";
part "experiment_state.dart";

class ExperimentBloc extends Bloc<ExperimentEvent, ExperimentState> {
  final SessionRepository _sessionRepository;
  static const int _maxTurns = 20;

  ExperimentBloc({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository, super(const ExperimentInitial()) {
    on<ExperimentStart>(_onStart);
    on<MutationChange>(_onMutationChange);
    on<MutationSetLoad>(_onMutationSetLoad);
    on<Evaluate>(_onEvaluate);
  }

  void _onStart(ExperimentStart event, Emitter<ExperimentState> emit) {
    if (state is! ExperimentInitial) return;
    emit(ExperimentActive(
      sessionId: event.sessionId,
      protein: event.protein,
      currentMutations: const [],
      history: const [],
      lastScore: 1.0,
      turnCount: 0,
      isEvaluating: false
    ));
  }

  void _onMutationChange(MutationChange event, Emitter<ExperimentState> emit) {
    final current = state;
    if (current is! ExperimentActive || current.isEvaluating) return;

    final updatedMutations = List<(int pos, String aa)>.from(current.currentMutations);
    final index = updatedMutations.indexWhere((m) => m.$1 == event.position);

    if (index != -1) {
      updatedMutations[index] = (event.position, event.aminoAcid);
    } else {
      updatedMutations.add((event.position, event.aminoAcid));
    }

    emit(current.copyWith(currentMutations: updatedMutations));
  }

  void _onMutationSetLoad(MutationSetLoad event, Emitter<ExperimentState> emit) {
    final current = state;
    if (current is! ExperimentActive || current.isEvaluating) return;

    emit(current.copyWith(currentMutations: List<(int pos, String aa)>.from(event.mutations)));
  }

  Future<void> _onEvaluate(Evaluate event, Emitter<ExperimentState> emit) async {
    final current = state;
    if (current is! ExperimentActive || current.isEvaluating || current.currentMutations.isEmpty) return;

    emit(current.copyWith(isEvaluating: true));

    final mutant = _buildMutant(current.currentMutations, current.protein.wildtypeSequence);
    try {
      final evaluationResult = await _sessionRepository.evaluate(
          sessionId: current.sessionId,
          pdbId: current.protein.pdbId,
          mutant: mutant
      );

      final newEntry = ExperimentEntry(
        mutant: evaluationResult.mutant,
        score: evaluationResult.score,
        turnCount: evaluationResult.turnCount
      );

      final updatedHistory = [...current.history, newEntry];

      if (evaluationResult.turnCount >= _maxTurns) {
        await _finishExperiment(updatedHistory, emit);
      } else {
        emit(current.copyWith(
          history: updatedHistory,
          lastScore: evaluationResult.score,
          turnCount: evaluationResult.turnCount,
          isEvaluating: false
        ));
      }
    } on ApiException {
      emit(current.copyWith(isEvaluating: false));
    }
  }

  Future<void> _finishExperiment(List<ExperimentEntry> history, Emitter<ExperimentState> emit) async {
    final bestScore = history.map((e) => e.score).reduce((a, b) => a > b ? a : b);
    Highscore highscore;
    try {
      highscore = await _sessionRepository.getHighscore();
    } on ApiException {
      highscore = Highscore(username: "", score: 0);
    }

    emit(ExperimentFinished(
      history: history,
      bestScore: bestScore,
      highscore: highscore
    ));
  }

  String _buildMutant(List<(int pos, String aa)> mutations, String wildtype) {
    final sorted = List<(int pos, String aa)>.from(mutations)
      ..sort((a, b) => a.$1.compareTo(b.$1));

    final mutationStrings = sorted.map((m) {
      final wildtypeAA = wildtype[m.$1 - 1];
      return "$wildtypeAA${m.$1}${m.$2}";
    });

    return mutationStrings.join(":");
  }
}