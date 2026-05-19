part of "session_manager_bloc.dart";

sealed class SessionManagerState extends Equatable {
  const SessionManagerState();

  @override
  List<Object?> get props => [];
}

final class SessionManagerInitial extends SessionManagerState {
  const SessionManagerInitial();
}

final class SessionManagerLoading extends SessionManagerState {
  const SessionManagerLoading();
}

final class SessionManagerActive extends SessionManagerState {
  final int sessionId;
  final String pdbId;

  const SessionManagerActive({required this.sessionId, required this.pdbId});

  @override
  List<Object?> get props => [sessionId, pdbId];
}

final class SessionManagerFinished extends SessionManagerState {
  final int sessionId;
  final String pdbId;
  final double score;
  final double highscore;

  const SessionManagerFinished({
    required this.sessionId,
    required this.pdbId,
    required this.score,
    required this.highscore,
  });

  @override
  List<Object?> get props => [sessionId, pdbId, score, highscore];
}

final class SessionManagerError extends SessionManagerState {
  final String message;

  const SessionManagerError(this.message);

  @override
  List<Object?> get props => [message];
}