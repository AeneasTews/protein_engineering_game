import "package:app/data/repositories/session_repository.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:app/data/api_exception.dart";
import "package:app/data/models/highscore.dart";

part "session_manager_event.dart";
part "session_manager_state.dart";

class SessionManagerBloc
    extends Bloc<SessionManagerEvent, SessionManagerState> {
  final SessionRepository _sessionRepository;

  SessionManagerBloc({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository,
      super(const SessionManagerInitial()) {
    on<SessionManagerCreate>(_onCreate);
    on<SessionManagerFinish>(_onFinish);
    on<SessionManagerClose>((_, emit) => emit(const SessionManagerInitial()));
  }

  Future<void> _onCreate(
    SessionManagerCreate event,
    Emitter<SessionManagerState> emit,
  ) async {
    if (state is! SessionManagerInitial) return;
    emit(const SessionManagerLoading());
    try {
      int sessionId = await _sessionRepository.createSession(
        event.username,
        event.pdbId,
      );
      emit(SessionManagerActive(sessionId: sessionId, pdbId: event.pdbId));
    } on ApiException catch (e) {
      emit(SessionManagerError("Failed to create session: ${e.statusCode}"));
    } catch (e) {
      emit(SessionManagerError("Unknown error: $e"));
    }
  }

  Future<void> _onFinish(
    SessionManagerFinish event,
    Emitter<SessionManagerState> emit,
  ) async {
    final current = state;
    if (current is! SessionManagerActive) return;

    Highscore highscore;
    try {
      highscore = await _sessionRepository.getHighscore(pdbId: current.pdbId);
    } on ApiException {
      highscore = const Highscore(username: "", score: 0);
    }

    emit(
      SessionManagerFinished(
        sessionId: current.sessionId,
        pdbId: current.pdbId,
        bestScore: event.score,
        highscore: highscore,
      ),
    );
  }
}
