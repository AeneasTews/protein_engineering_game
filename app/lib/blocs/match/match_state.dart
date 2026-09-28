part of "match_bloc.dart";

enum MatchPhase { countdown, running, finished }

final class MatchState extends Equatable {
  final MatchInfo match;
  final MatchPhase phase;
  // Until the start during the countdown, until the end while running.
  final Duration remaining;
  final PlayerProgress opponent;
  final bool opponentConnected;
  // Bumped whenever the opponent improves their best, so the UI can react to each one.
  final int opponentNewBestCount;
  final MatchResult? result;

  const MatchState({
    required this.match,
    required this.phase,
    required this.remaining,
    required this.opponent,
    required this.opponentConnected,
    required this.opponentNewBestCount,
    this.result,
  });

  factory MatchState.initial(MatchInfo match) => MatchState(
    match: match,
    phase: MatchPhase.countdown,
    remaining: Duration.zero,
    opponent: match.opponent,
    opponentConnected: match.opponentConnected,
    opponentNewBestCount: 0,
  ).atTime(match.serverNow());

  MatchState atTime(DateTime serverNow) {
    if (phase == MatchPhase.finished) return this;
    if (serverNow.isBefore(match.startsAt)) {
      return copyWith(phase: MatchPhase.countdown, remaining: match.startsAt.difference(serverNow));
    }
    final left = match.endsAt.difference(serverNow);
    // At zero the phase stays "running" until the server's match_end arrives.
    return copyWith(phase: MatchPhase.running, remaining: left.isNegative ? Duration.zero : left);
  }

  MatchState copyWith({
    MatchInfo? match,
    MatchPhase? phase,
    Duration? remaining,
    PlayerProgress? opponent,
    bool? opponentConnected,
    int? opponentNewBestCount,
    MatchResult? result,
  }) => MatchState(
    match: match ?? this.match,
    phase: phase ?? this.phase,
    remaining: remaining ?? this.remaining,
    opponent: opponent ?? this.opponent,
    opponentConnected: opponentConnected ?? this.opponentConnected,
    opponentNewBestCount: opponentNewBestCount ?? this.opponentNewBestCount,
    result: result ?? this.result,
  );

  @override
  List<Object?> get props => [match, phase, remaining, opponent, opponentConnected, opponentNewBestCount, result];
}
