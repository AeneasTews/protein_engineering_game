import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../blocs/match/match_bloc.dart";
import "../constants.dart";
import "../score_format.dart";

String formatClock(Duration duration) {
  // Round up so the clock shows 0:00 only once time is really up.
  final seconds = (duration.inMilliseconds / 1000).ceil();
  return "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, "0")}";
}

/// Replaces the practice round counter during a match: you vs. opponent around the match clock.
class MatchBar extends StatelessWidget {
  const MatchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: GameLayout.gameBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: GameLayout.gameBarHorizontalPadding),
      child: BlocBuilder<MatchBloc, MatchState>(
        builder: (context, match) {
          final protein = match.match.protein;
          final maxTurns = match.match.maxTurns;
          final isWarning = match.phase == MatchPhase.running && match.remaining <= MatchRules.clockWarning;

          return Row(
            children: [
              Text("${protein.name}  ${protein.pdbId}", style: textTheme.titleMedium),
              const Spacer(),
              BlocBuilder<ExperimentBloc, ExperimentState>(
                builder: (context, experiment) {
                  if (experiment is! ExperimentActive) return const SizedBox.shrink();
                  final best = experiment.history.isEmpty
                      ? null
                      : experiment.history.map((e) => e.score).reduce((a, b) => a > b ? a : b);
                  return _PlayerSummary(
                    label: "YOU",
                    bestScore: best,
                    turnCount: experiment.turnCount,
                    maxTurns: maxTurns,
                    color: colors.primary,
                  );
                },
              ),
              const SizedBox(width: 32),
              Text(
                match.phase == MatchPhase.countdown ? "--:--" : formatClock(match.remaining),
                style: textTheme.titleLarge?.copyWith(
                  fontSize: MatchLayout.clockFontSize,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isWarning ? colors.error : null,
                ),
              ),
              const SizedBox(width: 32),
              _PlayerSummary(
                label: match.opponent.nickname.toUpperCase(),
                bestScore: match.opponent.bestScore,
                turnCount: match.opponent.turnCount,
                maxTurns: maxTurns,
                color: colors.tertiary,
                connected: match.opponentConnected,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: match.phase == MatchPhase.finished ? null : () => _confirmForfeit(context),
                icon: const Icon(Icons.flag_outlined),
                label: const Text("Forfeit"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmForfeit(BuildContext context) async {
    final matchBloc = context.read<MatchBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Forfeit the match?"),
        content: const Text("Your opponent wins immediately."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text("Keep playing")),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text("Forfeit")),
        ],
      ),
    );
    if (confirmed == true) matchBloc.add(const MatchForfeitRequested());
  }
}

class _PlayerSummary extends StatelessWidget {
  final String label;
  final double? bestScore;
  final int turnCount;
  final int maxTurns;
  final Color color;
  final bool? connected;

  const _PlayerSummary({
    required this.label,
    required this.bestScore,
    required this.turnCount,
    required this.maxTurns,
    required this.color,
    this.connected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (connected != null) ...[
          Tooltip(
            message: connected! ? "Connected" : "Disconnected — they forfeit if they don't return",
            child: Container(
              width: MatchLayout.connectionDotSize,
              height: MatchLayout.connectionDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected! ? Colors.greenAccent : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelSmall?.copyWith(color: color)),
            Text("best ${formatScore(bestScore)}  ·  $turnCount/$maxTurns", style: textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}

/// Big 3-2-1 shown over the game screen until the match starts. Players can already plan mutations.
class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchBloc, MatchState>(
      buildWhen: (prev, next) => prev.phase != next.phase || prev.remaining.inSeconds != next.remaining.inSeconds,
      builder: (context, state) {
        if (state.phase != MatchPhase.countdown) return const SizedBox.shrink();
        final seconds = (state.remaining.inMilliseconds / 1000).ceil();
        return IgnorePointer(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$seconds",
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: MatchLayout.countdownFontSize,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  "vs ${state.opponent.nickname} — highest stability wins",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
