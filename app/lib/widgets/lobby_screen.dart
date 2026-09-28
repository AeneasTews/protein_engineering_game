import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/connect/connect_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../blocs/lobby/lobby_bloc.dart";
import "../blocs/match/match_bloc.dart";
import "../blocs/protein_library/protein_library_bloc.dart";
import "../constants.dart";
import "../data/models/match_models.dart";
import "../data/models/protein.dart";
import "../data/repositories/session_repository.dart";
import "game_screen.dart";
import "protein_library_screen.dart";

class LobbyScreen extends StatefulWidget {
  final ServerConnection connection;
  final VoidCallback onLeave;

  const LobbyScreen({super.key, required this.connection, required this.onLeave});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  // null = let the server pick a random protein.
  String? _selectedPdbId;

  void _openMatch(BuildContext context, MatchInfo match) {
    final navigator = Navigator.of(context);
    // A rematch can start while the previous result screen is still open.
    navigator.popUntil((route) => route.isFirst);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => MatchBloc(match: match, matchRepository: widget.connection.matchRepository),
          child: BlocProvider(
            create: (context) => ExperimentBloc(sessionRepository: context.read<SessionRepository>())
              ..add(
                ExperimentStart(
                  sessionId: match.sessionId,
                  protein: match.protein,
                  maxTurns: match.maxTurns,
                  playerToken: widget.connection.identity.token,
                  initialHistory: match.ownHistory,
                  lockReason: context.read<MatchBloc>().state.phase == MatchPhase.countdown ? MatchText.getReady : null,
                ),
              ),
            child: GameScreen(protein: match.protein, isMatch: true),
          ),
        ),
      ),
    );
    context.read<LobbyBloc>().add(const LobbyMatchOpened());
  }

  void _openPractice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Practice")),
          body: const ProteinLibraryScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.connection.identity;
    final textTheme = Theme.of(context).textTheme;

    return MultiBlocListener(
      listeners: [
        BlocListener<LobbyBloc, LobbyState>(
          listenWhen: (prev, next) => next.pendingMatch != null && prev.pendingMatch != next.pendingMatch,
          listener: (context, state) => _openMatch(context, state.pendingMatch!),
        ),
        BlocListener<LobbyBloc, LobbyState>(
          listenWhen: (prev, next) => next.noticeId != prev.noticeId && next.notice != null,
          listener: (context, state) =>
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.notice!))),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text("MutateIt — Lobby"),
          actions: [
            BlocBuilder<LobbyBloc, LobbyState>(
              buildWhen: (prev, next) => prev.connected != next.connected,
              builder: (context, state) => Chip(
                avatar: Icon(
                  state.connected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: state.connected ? Colors.greenAccent : Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  state.connected
                      ? "${identity.nickname} @ ${Uri.parse(widget.connection.baseUrl).host}"
                      : "Reconnecting…",
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _openPractice(context),
              icon: const Icon(Icons.science_outlined),
              label: const Text("Practice"),
            ),
            TextButton.icon(onPressed: widget.onLeave, icon: const Icon(Icons.logout), label: const Text("Leave")),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Challenges(),
                    Row(
                      children: [
                        Text("Players online", style: textTheme.titleLarge),
                        const Spacer(),
                        _ProteinPicker(
                          selectedPdbId: _selectedPdbId,
                          onChanged: (pdbId) => setState(() => _selectedPdbId = pdbId),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _PlayerList(pdbId: _selectedPdbId)),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            const SizedBox(
              width: MatchLayout.lobbyPanelWidth,
              child: Padding(padding: EdgeInsets.all(16), child: _SidePanel()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProteinPicker extends StatelessWidget {
  final String? selectedPdbId;
  final ValueChanged<String?> onChanged;

  const _ProteinPicker({required this.selectedPdbId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProteinLibraryBloc, ProteinLibraryState>(
      builder: (context, state) {
        final proteins = state is ProteinLibraryLoaded ? state.proteins : const <Protein>[];
        return DropdownButton<String?>(
          value: selectedPdbId,
          hint: const Text("Random protein"),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text("Random protein")),
            for (final protein in proteins)
              DropdownMenuItem<String?>(value: protein.pdbId, child: Text("${protein.name} (${protein.pdbId})")),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _Challenges extends StatelessWidget {
  const _Challenges();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LobbyBloc, LobbyState>(
      buildWhen: (prev, next) => prev.incoming != next.incoming || prev.outgoing != next.outgoing,
      builder: (context, state) {
        final lobby = context.read<LobbyBloc>();
        final outgoing = state.outgoing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final challenge in state.incoming)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(challenge.rematch ? Icons.replay : Icons.sports_esports),
                  title: Text(
                    challenge.rematch
                        ? "${challenge.nickname} wants a rematch"
                        : "${challenge.nickname} challenges you",
                  ),
                  subtitle: Text(challenge.pdbId == null ? "Random protein" : "Protein ${challenge.pdbId}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () =>
                            lobby.add(LobbyChallengeAnswered(challengeId: challenge.challengeId, accept: false)),
                        child: const Text("Decline"),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () =>
                            lobby.add(LobbyChallengeAnswered(challengeId: challenge.challengeId, accept: true)),
                        child: const Text("Accept"),
                      ),
                    ],
                  ),
                ),
              ),
            if (outgoing != null)
              Card(
                child: ListTile(
                  leading: const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text("Waiting for ${outgoing.nickname} to accept…"),
                  trailing: TextButton(
                    onPressed: () => lobby.add(const LobbyChallengeCancelled()),
                    child: const Text("Cancel"),
                  ),
                ),
              ),
            if (state.incoming.isNotEmpty || outgoing != null) const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _PlayerList extends StatelessWidget {
  final String? pdbId;

  const _PlayerList({required this.pdbId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LobbyBloc, LobbyState>(
      builder: (context, state) {
        if (state.players.isEmpty) {
          return Center(
            child: Text(
              "Nobody else is here yet.\nAsk a friend to connect to this server.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return ListView(
          children: [
            for (final player in state.players)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(player.nickname),
                  subtitle: Text(player.inMatch ? "In a match" : "Available"),
                  trailing: FilledButton.tonal(
                    onPressed: player.inMatch || state.outgoing != null || !state.connected
                        ? null
                        : () => context.read<LobbyBloc>().add(
                            LobbyChallengeRequested(playerId: player.playerId, pdbId: pdbId),
                          ),
                    child: const Text("Challenge"),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("How a match works", style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          "You and your opponent get the same protein, the same number of turns and one shared clock. "
          "Each turn, submit a set of mutations and see its stability score. "
          "When time runs out (or both of you are out of turns), the higher best score wins. "
          "You'll see your opponent's best score live — but their mutations stay secret until the end.",
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text("Leaderboard", style: textTheme.titleLarge),
            const Spacer(),
            IconButton(
              tooltip: "Refresh",
              onPressed: () => context.read<LobbyBloc>().add(const LobbyLeaderboardRequested()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Expanded(
          child: BlocBuilder<LobbyBloc, LobbyState>(
            buildWhen: (prev, next) => prev.leaderboard != next.leaderboard,
            builder: (context, state) {
              if (state.leaderboard.isEmpty) {
                return Text("No matches played yet.", style: textTheme.bodyMedium);
              }
              return ListView(
                children: [
                  for (final (index, entry) in state.leaderboard.indexed)
                    ListTile(
                      dense: true,
                      leading: Text("${index + 1}.", style: textTheme.titleMedium),
                      title: Text(entry.nickname),
                      trailing: Text("${entry.wins}W  ${entry.losses}L  ${entry.draws}D"),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
