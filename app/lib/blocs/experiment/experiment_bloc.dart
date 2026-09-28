import 'package:app/data/api_exception.dart';
import 'package:equatable/equatable.dart';
import '../../constants.dart';
import '../../data/models/experiment_entry.dart';
import '../../data/models/protein.dart';
import '../../data/models/trajectory_step.dart';
import "package:flutter_bloc/flutter_bloc.dart";
import '../../data/repositories/session_repository.dart';

part "experiment_event.dart";
part "experiment_state.dart";

class ExperimentBloc extends Bloc<ExperimentEvent, ExperimentState> {
  final SessionRepository _sessionRepository;
  String? _playerToken;

  ExperimentBloc({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository,
      super(const ExperimentInitial()) {
    on<ExperimentStart>(_onStart);
    on<ExperimentLockChanged>(_onLockChanged);
    on<MutationChange>(_onMutationChange);
    on<MutationSetLoad>(_onMutationSetLoad);
    on<Evaluate>(_onEvaluate);
    on<ExperimentClose>((_, emit) {
      if (state is! ExperimentFinished) return;
      emit(ExperimentInitial());
    });
  }

  bool get _isMatch => _playerToken != null;

  void _onStart(ExperimentStart event, Emitter<ExperimentState> emit) {
    if (state is! ExperimentInitial) return;
    _playerToken = event.playerToken;
    final history = event.initialHistory
        .map((step) => ExperimentEntry(mutant: step.mutant, score: step.score, turnCount: step.turnCount))
        .toList();
    emit(
      ExperimentActive(
        sessionId: event.sessionId,
        protein: event.protein,
        currentMutations: const [],
        history: history,
        lastScore: history.isEmpty ? 1.0 : history.last.score,
        turnCount: history.isEmpty ? 0 : history.last.turnCount,
        maxTurns: event.maxTurns,
        isEvaluating: false,
        lockReason: event.lockReason,
      ),
    );
  }

  void _onLockChanged(ExperimentLockChanged event, Emitter<ExperimentState> emit) {
    final current = state;
    if (current is! ExperimentActive) return;
    // Once out of turns, a match experiment stays locked whatever the clock says.
    if (event.lockReason == null && current.turnCount >= current.maxTurns) return;
    emit(current.withLock(event.lockReason));
  }

  void _onMutationChange(MutationChange event, Emitter<ExperimentState> emit) {
    final current = state;
    if (current is! ExperimentActive || current.isEvaluating) return;

    final updatedMutations = List<(int pos, String aa)>.from(current.currentMutations);
    final index = updatedMutations.indexWhere((m) => m.$1 == event.position);
    final wildtypeAa = current.protein.wildtypeSequence[event.position - 1];

    if (index != -1) {
      if (updatedMutations[index].$2 != event.aminoAcid && event.aminoAcid != wildtypeAa) {
        updatedMutations[index] = (event.position, event.aminoAcid);
      } else {
        updatedMutations.removeAt(index);
      }
    } else {
      if (event.aminoAcid != wildtypeAa) updatedMutations.add((event.position, event.aminoAcid));
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
    if (current is! ExperimentActive || current.isEvaluating || current.isLocked || current.currentMutations.isEmpty) {
      return;
    }

    emit(current.copyWith(isEvaluating: true));

    final mutant = _buildMutant(current.currentMutations, current.protein.wildtypeSequence);
    try {
      final evaluationResult = await _sessionRepository.evaluate(
        sessionId: current.sessionId,
        pdbId: current.protein.pdbId,
        mutant: mutant,
        playerToken: _playerToken,
      );

      final newEntry = ExperimentEntry(
        mutant: evaluationResult.mutant,
        score: evaluationResult.score,
        turnCount: evaluationResult.turnCount,
      );

      final updatedHistory = [...current.history, newEntry];

      final outOfTurns = evaluationResult.turnCount >= current.maxTurns;
      if (outOfTurns && !_isMatch) {
        _finishExperiment(updatedHistory, emit);
        return;
      }
      // Build on the latest state: the match may have locked it while the request was in flight.
      final latest = state is ExperimentActive ? state as ExperimentActive : current;
      final updated = latest.copyWith(
        history: updatedHistory,
        lastScore: evaluationResult.score,
        turnCount: evaluationResult.turnCount,
        isEvaluating: false,
      );
      emit(outOfTurns ? updated.withLock(MatchText.outOfTurns) : updated);
    } on ApiException catch (e) {
      // 409: the match clock has run out (or not started) on the server.
      final latest = state is ExperimentActive ? state as ExperimentActive : current;
      final reverted = latest.copyWith(isEvaluating: false);
      emit(_isMatch && e.statusCode == 409 ? reverted.withLock(MatchText.matchOver) : reverted);
    }
  }

  void _finishExperiment(List<ExperimentEntry> history, Emitter<ExperimentState> emit) {
    final bestScore = history.map((e) => e.score).reduce((a, b) => a > b ? a : b);
    emit(ExperimentFinished(history: history, bestScore: bestScore));
  }

  String _buildMutant(List<(int pos, String aa)> mutations, String wildtype) {
    final sorted = List<(int pos, String aa)>.from(mutations)..sort((a, b) => a.$1.compareTo(b.$1));

    final mutationStrings = sorted.map((m) {
      final wildtypeAA = wildtype[m.$1 - 1];
      return "$wildtypeAA${m.$1}${m.$2}";
    });

    return mutationStrings.join(":");
  }
}
