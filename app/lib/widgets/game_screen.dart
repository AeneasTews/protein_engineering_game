import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../blocs/session_manager/session_manager_bloc.dart";
import "../data/models/protein.dart";
import "../molstar/molstar_controller.dart";
import "../widgets/history_panel.dart";
import "../widgets/sequence_panel.dart";
import "../widgets/structure_panel.dart";

class GameScreen extends StatefulWidget {
  final Protein protein;

  const GameScreen({super.key, required this.protein});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final MolstarController _molstar = MolstarController();

  double _leftFraction = 0.2;
  double _midFraction  = 0.6;
  static const double _minFraction = 0.15;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExperimentBloc, ExperimentState>(
      listenWhen: (_, next) => next is ExperimentFinished,
      listener: (context, state) async {
        if (state is! ExperimentFinished) return;
        context
            .read<SessionManagerBloc>()
            .add(SessionManagerFinish(score: state.bestScore));
        await _showFinishDialog(context, state);

        if (!context.mounted) return;
        context.read<ExperimentBloc>().add(ExperimentClose());
        context.read<SessionManagerBloc>().add(SessionManagerClose());
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            _GameBar(protein: widget.protein),
            const Divider(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const divW = 8.0;
                  final panelW = constraints.maxWidth - 2 * divW;
                  final rightFraction = 1 - _leftFraction - _midFraction;

                  return Row(
                    children: [
                      SizedBox(
                        width: panelW * _leftFraction,
                        child: SequencePanel(
                          protein: widget.protein,
                          onResidueTap: (position) => _molstar.selectResidue(position),
                        ),
                      ),
                      _DragDivider(
                        onDragDelta: (dx) => setState(() {
                          _leftFraction = (_leftFraction + dx / panelW).clamp(_minFraction, 1 - _midFraction - _minFraction);
                        }),
                      ),
                      SizedBox(
                        width: panelW * _midFraction,
                        child: StructurePanel(
                          pdbId: widget.protein.pdbId,
                          wildtypeSequence: widget.protein.wildtypeSequence,
                          controller: _molstar,
                          onResidueClick: _showPickerFromStructure,
                        ),
                      ),
                      _DragDivider(
                        onDragDelta: (dx) => setState(() {
                          _midFraction = (_midFraction + dx / panelW).clamp(_minFraction, 1 - _leftFraction - _minFraction);
                        }),
                      ),
                      SizedBox(
                        width: panelW * rightFraction,
                        child: const HistoryPanel(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerFromStructure(int seqPosition, double x, double y) {
    if (!mounted) return;

    final wildtypeAa = widget.protein.wildtypeSequence[seqPosition - 1];
    final experimentBloc = context.read<ExperimentBloc>();

    if (experimentBloc.state is! ExperimentActive) return;

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        x + 8,
        y + 8,
        x + 408,
        0,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Text(
            "Position: $seqPosition  |  Wildtype: $wildtypeAa",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 400,
            height: 220,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
              ),
              itemCount: aminoAcids.length,
              itemBuilder: (menuContext, index) {
                final aminoAcid = aminoAcids[index];
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(menuContext).pop();
                    if (aminoAcid != wildtypeAa) {
                      experimentBloc.add(MutationChange(
                        position: seqPosition,
                        aminoAcid: aminoAcid,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        aminoAcid,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (aminoAcid == wildtypeAa)
                        Text(
                          "WT",
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(fontSize: 8, height: 0.8),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showFinishDialog(BuildContext context, ExperimentFinished state) async {
    final Widget content;
    if (state.bestScore < state.highscore.score) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreRow(label: "HIGHSCORE by ${state.highscore.username}", value: state.highscore.score),
          const SizedBox(height: 12),
          _ScoreRow(label: "YOUR BEST", value: state.bestScore)
        ]
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreRow(label: "NEW HIGHSCORE", value: state.bestScore)
        ]
      );
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Experiment Complete"),
        content: SizedBox(
          width: 340,
          child: content
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Back to library"),
          ),
        ],
      ),
    );
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
          Text(protein.name,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 10),
          Text(protein.pdbId,
              style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          BlocBuilder<ExperimentBloc, ExperimentState>(
            builder: (context, state) {
              if (state is! ExperimentActive) return const SizedBox.shrink();
              return Row(
                children: [
                  Text("ROUND",
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text(
                    "${state.turnCount} / 20",
                    style:
                    Theme.of(context).textTheme.titleLarge?.copyWith(
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

class _DragDivider extends StatelessWidget {
  final ValueChanged<double> onDragDelta;

  const _DragDivider({required this.onDragDelta});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDragDelta(d.delta.dx),
        child: SizedBox(
          width: 8,
          child: Center(
            child: Container(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}