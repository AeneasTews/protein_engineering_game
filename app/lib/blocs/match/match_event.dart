part of "match_bloc.dart";

sealed class MatchEvent extends Equatable {
  const MatchEvent();

  @override
  List<Object?> get props => [];
}

final class MatchTicked extends MatchEvent {
  const MatchTicked();
}

final class MatchMessageReceived extends MatchEvent {
  final ServerMessage message;

  const MatchMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

final class MatchForfeitRequested extends MatchEvent {
  const MatchForfeitRequested();
}
