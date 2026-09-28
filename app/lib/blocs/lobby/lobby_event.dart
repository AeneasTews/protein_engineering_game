part of "lobby_bloc.dart";

sealed class LobbyEvent extends Equatable {
  const LobbyEvent();

  @override
  List<Object?> get props => [];
}

final class LobbyStarted extends LobbyEvent {
  const LobbyStarted();
}

final class LobbyLeaderboardRequested extends LobbyEvent {
  const LobbyLeaderboardRequested();
}

final class LobbyChallengeRequested extends LobbyEvent {
  final String playerId;
  // null lets the server pick a random protein.
  final String? pdbId;

  const LobbyChallengeRequested({required this.playerId, this.pdbId});

  @override
  List<Object?> get props => [playerId, pdbId];
}

final class LobbyChallengeAnswered extends LobbyEvent {
  final String challengeId;
  final bool accept;

  const LobbyChallengeAnswered({required this.challengeId, required this.accept});

  @override
  List<Object?> get props => [challengeId, accept];
}

final class LobbyChallengeCancelled extends LobbyEvent {
  const LobbyChallengeCancelled();
}

final class LobbyRematchRequested extends LobbyEvent {
  const LobbyRematchRequested();
}

// The lobby screen has navigated to the pending match.
final class LobbyMatchOpened extends LobbyEvent {
  const LobbyMatchOpened();
}
