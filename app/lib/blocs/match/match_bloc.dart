import "dart:async";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../../constants.dart";
import "../../data/models/match_models.dart";
import "../../data/repositories/match_repository.dart";

part "match_event.dart";
part "match_state.dart";

class MatchBloc extends Bloc<MatchEvent, MatchState> {
  final MatchRepository _matchRepository;
  late final StreamSubscription<ServerMessage> _messageSubscription;
  late final Timer _ticker;

  MatchBloc({required MatchInfo match, required MatchRepository matchRepository})
    : _matchRepository = matchRepository,
      super(MatchState.initial(match)) {
    on<MatchTicked>(_onTicked);
    on<MatchMessageReceived>(_onMessage);
    on<MatchForfeitRequested>((_, _) => _matchRepository.forfeit());

    _messageSubscription = _matchRepository.messages.listen((m) => add(MatchMessageReceived(m)));
    _ticker = Timer.periodic(MatchRules.clockTick, (_) => add(const MatchTicked()));
  }

  void _onTicked(MatchTicked event, Emitter<MatchState> emit) {
    if (state.phase == MatchPhase.finished) return;
    emit(state.atTime(state.match.serverNow()));
  }

  void _onMessage(MatchMessageReceived event, Emitter<MatchState> emit) {
    final message = event.message;
    switch (message) {
      case MatchStarted(:final match) when match.matchId == state.match.matchId:
        // Resumed after a reconnect: resync the clock and the opponent's progress.
        emit(
          state
              .copyWith(match: match, opponent: match.opponent, opponentConnected: match.opponentConnected)
              .atTime(match.serverNow()),
        );
      case OpponentProgressed(:final turnCount, :final bestScore, :final newBest):
        emit(
          state.copyWith(
            opponent: state.opponent.copyWith(turnCount: turnCount, bestScore: bestScore),
            opponentNewBestCount: newBest ? state.opponentNewBestCount + 1 : null,
          ),
        );
      case OpponentConnectionChanged(:final connected):
        emit(state.copyWith(opponentConnected: connected));
      case MatchEnded(:final result) when result.matchId == state.match.matchId:
        emit(state.copyWith(phase: MatchPhase.finished, result: result));
      default:
        break;
    }
  }

  @override
  Future<void> close() async {
    _ticker.cancel();
    await _messageSubscription.cancel();
    return super.close();
  }
}
