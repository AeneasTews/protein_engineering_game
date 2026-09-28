import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../../data/models/match_models.dart";
import "../../data/repositories/match_repository.dart";

part "lobby_event.dart";
part "lobby_state.dart";

class LobbyBloc extends Bloc<LobbyEvent, LobbyState> {
  final MatchRepository _matchRepository;
  final PlayerIdentity _identity;

  LobbyBloc({required MatchRepository matchRepository, required PlayerIdentity identity})
    : _matchRepository = matchRepository,
      _identity = identity,
      super(LobbyState(connected: matchRepository.isConnected)) {
    on<LobbyStarted>(_onStarted);
    on<LobbyLeaderboardRequested>(_onLeaderboardRequested);
    on<LobbyChallengeRequested>((event, _) => _matchRepository.challenge(playerId: event.playerId, pdbId: event.pdbId));
    on<LobbyChallengeAnswered>(
      (event, _) => _matchRepository.respondToChallenge(challengeId: event.challengeId, accept: event.accept),
    );
    on<LobbyChallengeCancelled>((_, _) => _matchRepository.cancelChallenge());
    on<LobbyRematchRequested>((_, _) => _matchRepository.rematch());
    on<LobbyMatchOpened>((_, emit) => emit(state.copyWith(clearPendingMatch: true)));
  }

  Future<void> _onStarted(LobbyStarted event, Emitter<LobbyState> emit) async {
    add(const LobbyLeaderboardRequested());
    await emit.forEach<ServerMessage>(_matchRepository.messages, onData: _reduce);
  }

  Future<void> _onLeaderboardRequested(LobbyLeaderboardRequested event, Emitter<LobbyState> emit) async {
    try {
      emit(state.copyWith(leaderboard: await _matchRepository.getLeaderboard()));
    } catch (_) {
      // Keep the last known leaderboard; it's refreshed after every match.
    }
  }

  LobbyState _reduce(ServerMessage message) {
    switch (message) {
      case ConnectionChanged(:final connected):
        return state.copyWith(connected: connected);
      case LobbyUpdated(:final players):
        return state.copyWith(players: players.where((p) => p.playerId != _identity.playerId).toList());
      case ChallengeReceived(:final challenge):
        if (state.incoming.any((c) => c.challengeId == challenge.challengeId)) return state;
        return state.copyWith(incoming: [...state.incoming, challenge]);
      case ChallengeSent(:final challenge):
        return state.copyWith(outgoing: challenge);
      case ChallengeDeclined(:final by):
        return state.copyWith(clearOutgoing: true).withNotice("$by declined your challenge");
      case ChallengeCancelled(:final challengeId):
        return state.copyWith(
          incoming: state.incoming.where((c) => c.challengeId != challengeId).toList(),
          clearOutgoing: state.outgoing?.challengeId == challengeId,
        );
      case MatchStarted(:final match):
        // A resume for the match that's already open is handled by its MatchBloc.
        if (match.matchId == state.activeMatchId) return state;
        return state.copyWith(activeMatchId: match.matchId, pendingMatch: match, incoming: [], clearOutgoing: true);
      case MatchEnded():
        add(const LobbyLeaderboardRequested());
        return state.copyWith(clearActiveMatch: true);
      case ServerError(:final message):
        return state.withNotice(message);
      case OpponentProgressed() || OpponentConnectionChanged():
        return state;
    }
  }
}
