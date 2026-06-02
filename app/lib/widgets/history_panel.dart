import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../data/models/experiment_entry.dart";

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(),
          Divider(),
          _SubmitButton(),
          Divider(),
          _History(),
          Divider(),
          _HistoryGraph()
        ]
      )
    );
  }
}

class _PanelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
      builder: (context, state) {
        if (state is! ExperimentActive) return SizedBox.shrink();

        double? lastScore;
        double? bestScore;

        if (state.history.isNotEmpty) {
          lastScore = state.lastScore;
          bestScore = state.history.map((h) => h.score).reduce((a, b) => a > b ? a : b);
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              _StatBlock(score: lastScore, label: "Last"),
              const Spacer(),
              const VerticalDivider(),
              const Spacer(),
              _StatBlock(score: bestScore, label: "Best"),
              const Spacer()
            ]
          )
        );
      }
    );
  }
}

class _StatBlock extends StatelessWidget {
  final double? score;
  final String label;

  const _StatBlock({this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          score == null ? "-" : score!.toStringAsFixed(2),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _scoreColor(score, context)
          )
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
        )
      ],
    );
  }
}

Color? _scoreColor(double? score, BuildContext context) {
  const colorDelta = 0.1;  // constant which determines outside what range scores should be considered different from wildtype (+- 0.1 is still pretty much wildtype

  if (score == null) {
    return null;
  } else if (score < 0 - colorDelta) {
    return Theme.of(context).colorScheme.error;
  } else if (score > 0 + colorDelta) {
    return Theme.of(context).colorScheme.primary;
  } else {
    return null;
  }
}

class _SubmitButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
      builder: (context, state) {
        if (state is! ExperimentActive) return SizedBox.shrink();

        final isSubmittable = state.currentMutations.isNotEmpty;

        return FilledButton(
          onPressed: () {
            if (!isSubmittable) return;
            context.read<ExperimentBloc>().add(Evaluate());
          },
          style: FilledButton.styleFrom(
            backgroundColor: isSubmittable ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(double.infinity, 45)
          ),
          child: Text(
            isSubmittable ? "Submit ${state.currentMutations.length} mutation${state.currentMutations.length > 1 ? "s" : ""}" : "Add mutations first",
            style: Theme.of(context).textTheme.bodyMedium
          ),
        );
      }
    );
  }
}

class _History extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
      builder: (context, state) {
        if (state is! ExperimentActive) return SizedBox.shrink();
        return Expanded(
          child: ListView.builder(
            itemCount: state.history.length,
            itemBuilder: (context, index) {
              return _HistoryEntry(experimentEntry: state.history[state.history.length - index - 1]);
            }
          )
        );
      }
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  final ExperimentEntry experimentEntry;

  const _HistoryEntry({required this.experimentEntry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.onInverseSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Round ${experimentEntry.turnCount}",
                        style: Theme.of(context).textTheme.bodyLarge
                      ),
                      VerticalDivider(),
                      Text("Score:", style: Theme.of(context).textTheme.bodyLarge),
                      Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          experimentEntry.score.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _scoreColor(experimentEntry.score, context)
                          )
                        )
                      )
                    ]
                  )
                ),
                Divider(),
                Text(
                  experimentEntry.mutant,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    overflow: TextOverflow.ellipsis
                  )
                ),
              ]
            )
          ),
          TextButton(
            onPressed: () {
              context.read<ExperimentBloc>().add(MutationSetLoad(mutations: experimentEntry.mutations));
            },
            child: Icon(Icons.keyboard_backspace)
          )
        ]
      )
    );
  }
}

class _HistoryGraph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
        builder: (context, state) {
          if (state is! ExperimentActive || state.history.isEmpty) return const SizedBox.shrink();

          final history = state.history;
          final maxScore = history.map((e) => e.score).reduce((a, b) => a > b ? a : b);
          final minScore = history.map((e) => e.score).reduce((a, b) => a < b ? a : b);

          return AspectRatio(
            aspectRatio: 1.75,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: history.length < 2 ? 1.0 : history.last.turnCount.toDouble(),
                minY: minScore - 1,
                maxY: maxScore + 1,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1.0,
                  verticalInterval: history.length < 2 ? 1.0 : null,
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1.0,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      reservedSize: 30,
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _buildChartData(history),
                    isCurved: false,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  )
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedBarSpot) {
                        final FlSpot spot = touchedBarSpot.bar.spots[touchedBarSpot.spotIndex];
                        final int turn = spot.x.toInt();
                        final String score = spot.y.toStringAsFixed(3);
                        return LineTooltipItem(
                          "Turn $turn\n",
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSecondaryContainer
                          ),
                          children: [
                            TextSpan(
                              text: "Score: $score",
                              style: TextStyle(
                                color: _scoreColor(spot.y, context)
                              )
                            )
                          ]
                        );
                      }).toList();
                    }
                  )
                )
              ),
            ),
          );
        }
    );
  }

  List<FlSpot> _buildChartData(List<ExperimentEntry> history) {
    return history.map((e) => FlSpot(e.turnCount.toDouble(), e.score)).toList(growable: false);
  }
}