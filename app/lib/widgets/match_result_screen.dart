import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/lobby/lobby_bloc.dart";
import "../constants.dart";
import "../data/models/match_models.dart";
import "../data/models/protein.dart";
import "../data/models/trajectory_step.dart";
import "match_widgets.dart";

class MatchResultScreen extends StatelessWidget {
  final MatchResult result;
  final Protein protein;

  const MatchResultScreen({super.key, required this.result, required this.protein});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (title, titleColor) = switch (result.outcome) {
      MatchOutcome.won => ("Victory!", Colors.greenAccent),
      MatchOutcome.lost => ("Defeat", colors.error),
      MatchOutcome.draw => ("Draw", colors.onSurface),
    };

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MatchLayout.resultWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: textTheme.displayLarge?.copyWith(color: titleColor)),
                const SizedBox(height: 4),
                Text("${result.reason.label}  ·  ${protein.name} (${protein.pdbId})", style: textTheme.titleMedium),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PlayerCard(label: "You", player: result.you, color: colors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PlayerCard(
                        label: result.opponent.progress.nickname,
                        player: result.opponent,
                        color: colors.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (result.you.history.isNotEmpty || result.opponent.history.isNotEmpty)
                  _DuelChart(
                    you: result.you.history,
                    opponent: result.opponent.history,
                    youColor: colors.primary,
                    opponentColor: colors.tertiary,
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Back to lobby")),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () {
                        context.read<LobbyBloc>().add(const LobbyRematchRequested());
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text("Rematch"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String label;
  final MatchPlayerResult player;
  final Color color;

  const _PlayerCard({required this.label, required this.player, required this.color});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiLayout.cardBorderRadius),
        side: BorderSide(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.titleLarge?.copyWith(color: color)),
            const SizedBox(height: 8),
            Text("Best score  ${formatScore(player.progress.bestScore)}", style: textTheme.titleMedium),
            Text("Turns used  ${player.progress.turnCount}", style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text("Best variant", style: textTheme.labelSmall),
            SelectableText(player.bestMutant ?? "—", style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// Both players' scores per turn on one chart.
class _DuelChart extends StatelessWidget {
  final List<TrajectoryStep> you;
  final List<TrajectoryStep> opponent;
  final Color youColor;
  final Color opponentColor;

  const _DuelChart({required this.you, required this.opponent, required this.youColor, required this.opponentColor});

  @override
  Widget build(BuildContext context) {
    final scores = [...you, ...opponent].map((e) => e.score);
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxTurn = [...you, ...opponent].map((e) => e.turnCount).reduce((a, b) => a > b ? a : b);

    LineChartBarData line(List<TrajectoryStep> steps, Color color) => LineChartBarData(
      spots: steps.map((e) => FlSpot(e.turnCount.toDouble(), e.score)).toList(growable: false),
      color: color,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: false),
    );

    return AspectRatio(
      aspectRatio: UiLayout.historyChartAspectRatio * 1.2,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxTurn < 1 ? 1 : maxTurn.toDouble(),
          minY: minScore - UiLayout.chartScorePadding,
          maxY: maxScore + UiLayout.chartScorePadding,
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: UiLayout.chartAxisReservedSize),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: UiLayout.chartGridInterval,
                reservedSize: UiLayout.chartAxisReservedSize,
              ),
            ),
          ),
          lineBarsData: [
            if (you.isNotEmpty) line(you, youColor),
            if (opponent.isNotEmpty) line(opponent, opponentColor),
          ],
        ),
      ),
    );
  }
}
