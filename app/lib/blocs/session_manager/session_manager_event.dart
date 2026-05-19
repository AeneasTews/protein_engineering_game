part of "session_manager_bloc.dart";

sealed class SessionManagerEvent extends Equatable {
  const SessionManagerEvent();

  @override
  List<Object?> get props => [];
}

final class SessionManagerCreate extends SessionManagerEvent {
  final String username;
  final String pdbId;

  const SessionManagerCreate({required this.username, required this.pdbId});

  @override
  List<Object?> get props => [username, pdbId];
}

final class SessionManagerFinish extends SessionManagerEvent {
  final double score;

  const SessionManagerFinish({required this.score});

  @override
  List<Object?> get props => [score];
}

final class SessionManagerClose extends SessionManagerEvent {
  const SessionManagerClose();
}