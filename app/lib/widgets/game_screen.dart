import "package:app/blocs/experiment/experiment_bloc.dart";
import "package:app/widgets/history_panel.dart";
import "package:app/widgets/sequence_panel.dart";
import "package:app/widgets/structure_panel.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/session_manager/session_manager_bloc.dart";
import "../data/models/protein.dart";

class GameScreen extends StatelessWidget {
  final Protein protein;

  const GameScreen({super.key, required this.protein});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExperimentBloc, ExperimentState>(
      listenWhen: (_, nextState) => nextState is ExperimentFinished,
      listener: (context, state) async {
        if (state is! ExperimentFinished) return;
        context.read<SessionManagerBloc>().add(SessionManagerFinish(score: state.bestScore));
        await _showFinishDialog(context, state);

        if (!context.mounted) return;
        context.read<ExperimentBloc>().add(ExperimentClose());
        context.read<SessionManagerBloc>().add(SessionManagerClose());
      },
      child: Scaffold(
        body: Column(
          children: [
            _GameBar(protein: protein),
            const Divider(),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: SequencePanel(protein: protein)),
                  const VerticalDivider(),
                  Expanded(
                    child: StructurePanel(pdbId: protein.pdbId),
                  ),
                  const VerticalDivider(),
                  const Expanded(child: HistoryPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFinishDialog(BuildContext context, ExperimentFinished state) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Experiment Complete"),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScoreRow(label: "YOUR BEST", value: state.bestScore),
              const SizedBox(height: 12),
              _ScoreRow(label: "HIGH SCORE", value: state.highscore.score),
              const SizedBox(height: 24),
              if (state.bestScore > state.highscore.score)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text("🏆 New High Score!"),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Back to library"),
          ),
        ],
      ),
    );

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double value;

  const _ScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value.toStringAsFixed(2)),
      ],
    );
  }
}

class _GameBar extends StatelessWidget {
  final Protein protein;

  const _GameBar({required this.protein});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            protein.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 10),
          Text(
            protein.pdbId,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          BlocBuilder<ExperimentBloc, ExperimentState>(
            builder: (context, state) {
              if (state is! ExperimentActive) return const SizedBox.shrink();
              return Row(
                children: [
                  Text(
                    "ROUND",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${state.turnCount} / 20",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: state.turnCount >= 18
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}