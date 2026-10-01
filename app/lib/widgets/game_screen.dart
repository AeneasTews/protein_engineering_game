import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:bio_flutter/protein_viewer.dart" show ProteinViewerController;
import "../blocs/experiment/experiment_bloc.dart";
import "../blocs/protein_library/protein_library_bloc.dart";
import "../blocs/session_manager/session_manager_bloc.dart";
import "../constants.dart";
import "../score_format.dart";
import "../data/models/protein.dart";
import "../data/repositories/protein_repository.dart";
import "../data/models/protein_structure.dart";
import "../blocs/match/match_bloc.dart";
import "../widgets/history_panel.dart";
import "match_result_screen.dart";
import "match_widgets.dart";
import "../widgets/sequence_panel.dart";
import "../widgets/structure_panel.dart";

class GameScreen extends StatefulWidget {
  final Protein protein;
  // In a match a MatchBloc is provided above this screen, and the match (not the turn count)
  // decides when the game is over.
  final bool isMatch;

  const GameScreen({super.key, required this.protein, this.isMatch = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ProteinViewerController _viewerController = ProteinViewerController();
  ProteinStructure? _structure;
  Object? _structureLoadError;
  // The residue selected in the sequence panel or the 3D view, as a sequence position.
  int? _selectedPosition;

  double _leftFraction = GameLayout.initialLeftFraction;
  double _midFraction = GameLayout.initialMidFraction;

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  Future<void> _loadStructure() async {
    try {
      final structure = await context.read<ProteinRepository>().getStructure(widget.protein.pdbId);
      if (!mounted) return;
      setState(() => _structure = structure);
    } catch (e) {
      if (!mounted) return;
      setState(() => _structureLoadError = e);
    }
  }

  void _selectFromSequence(int position) {
    setState(() => _selectedPosition = position);
    final key = _structure?.keyAt(position);
    if (key != null) _viewerController.focusResidue(key);
  }

  // Changing the pending mutations clears the selection, as it always has.
  BlocListener _clearSelectionOnMutation() => BlocListener<ExperimentBloc, ExperimentState>(
    listenWhen: (prev, next) =>
        prev is ExperimentActive && next is ExperimentActive && prev.currentMutations != next.currentMutations,
    listener: (context, state) {
      if (_selectedPosition != null) setState(() => _selectedPosition = null);
    },
  );

  List<BlocListener> _matchListeners() => [
    BlocListener<MatchBloc, MatchState>(
      listenWhen: (prev, next) => prev.phase != next.phase,
      listener: (context, state) async {
        final experimentBloc = context.read<ExperimentBloc>();
        switch (state.phase) {
          case MatchPhase.countdown:
            experimentBloc.add(const ExperimentLockChanged(MatchText.getReady));
          case MatchPhase.running:
            experimentBloc.add(const ExperimentLockChanged(null));
          case MatchPhase.finished:
            experimentBloc.add(const ExperimentLockChanged(MatchText.matchOver));
            final result = state.result;
            if (result == null) return;
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MatchResultScreen(result: result, protein: widget.protein),
              ),
            );
        }
      },
    ),
    BlocListener<MatchBloc, MatchState>(
      listenWhen: (prev, next) => next.opponentNewBestCount > prev.opponentNewBestCount,
      listener: (context, state) =>
          _showToast(context, "${state.opponent.nickname} found a new best: ${formatScore(state.opponent.bestScore)}"),
    ),
    BlocListener<MatchBloc, MatchState>(
      listenWhen: (prev, next) => prev.opponentConnected != next.opponentConnected,
      listener: (context, state) => _showToast(
        context,
        state.opponentConnected
            ? "${state.opponent.nickname} is back"
            : "${state.opponent.nickname} disconnected — they forfeit if they don't return",
      ),
    ),
  ];

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: MatchLayout.opponentToastDuration,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  List<BlocListener> _practiceListeners() => [
    BlocListener<ExperimentBloc, ExperimentState>(
      listenWhen: (_, next) => next is ExperimentFinished,
      listener: (context, state) {
        if (state is! ExperimentFinished) return;
        context.read<SessionManagerBloc>().add(SessionManagerFinish(score: state.bestScore));
      },
    ),
    BlocListener<SessionManagerBloc, SessionManagerState>(
      listenWhen: (_, next) => next is SessionManagerFinished,
      listener: (context, state) async {
        if (state is! SessionManagerFinished) return;
        context.read<ProteinLibraryBloc>().add(HighscoreUpdated(pdbId: state.pdbId, highscore: state.highscore));

        await _showFinishDialog(context, state);

        if (!context.mounted) return;
        context.read<ExperimentBloc>().add(ExperimentClose());
        context.read<SessionManagerBloc>().add(SessionManagerClose());
        Navigator.of(context).pop();
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [_clearSelectionOnMutation(), ...widget.isMatch ? _matchListeners() : _practiceListeners()],
      child: Scaffold(body: Stack(children: [_gameLayout(), if (widget.isMatch) const CountdownOverlay()])),
    );
  }

  Widget _gameLayout() {
    return Column(
      children: [
        widget.isMatch ? const MatchBar() : _GameBar(protein: widget.protein),
        const Divider(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const divW = GameLayout.dividerWidth;
              final panelW = constraints.maxWidth - 2 * divW;
              final rightFraction = 1 - _leftFraction - _midFraction;

              return Row(
                children: [
                  SizedBox(
                    width: panelW * _leftFraction,
                    child: SequencePanel(
                      protein: widget.protein,
                      onResidueTap: _selectFromSequence,
                      selectedPosition: _selectedPosition,
                    ),
                  ),
                  _DragDivider(
                    onDragDelta: (dx) => setState(() {
                      _leftFraction = (_leftFraction + dx / panelW).clamp(
                        GameLayout.minPanelFraction,
                        1 - _midFraction - GameLayout.minPanelFraction,
                      );
                    }),
                  ),
                  SizedBox(
                    width: panelW * _midFraction,
                    child: StructurePanel(
                      structure: _structure,
                      loadError: _structureLoadError,
                      controller: _viewerController,
                      selectedPosition: _selectedPosition,
                      onSelectedPositionChanged: (position) => setState(() => _selectedPosition = position),
                      onResidueClick: _showPickerFromStructure,
                    ),
                  ),
                  _DragDivider(
                    onDragDelta: (dx) => setState(() {
                      _midFraction = (_midFraction + dx / panelW).clamp(
                        GameLayout.minPanelFraction,
                        1 - _leftFraction - GameLayout.minPanelFraction,
                      );
                    }),
                  ),
                  SizedBox(width: panelW * rightFraction, child: const HistoryPanel()),
                ],
              );
            },
          ),
        ),
      ],
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
        x + PickerMenuLayout.cursorOffset,
        y + PickerMenuLayout.cursorOffset,
        x + PickerMenuLayout.cursorOffset + PickerMenuLayout.menuWidth,
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
            width: PickerMenuLayout.menuWidth,
            height: PickerMenuLayout.menuHeight,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: PickerMenuLayout.gridCrossAxisCount,
                mainAxisSpacing: PickerMenuLayout.gridSpacing,
                crossAxisSpacing: PickerMenuLayout.gridSpacing,
              ),
              itemCount: AminoAcids.all.length,
              itemBuilder: (menuContext, index) {
                final aminoAcid = AminoAcids.all[index];
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(menuContext).pop();
                    if (aminoAcid != wildtypeAa) {
                      experimentBloc.add(MutationChange(position: seqPosition, aminoAcid: aminoAcid));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiLayout.cardBorderRadius)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(aminoAcid, style: Theme.of(context).textTheme.titleLarge),
                      if (aminoAcid == wildtypeAa)
                        Text(
                          "WT",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: PickerMenuLayout.wildtypeLabelFontSize,
                            height: PickerMenuLayout.wildtypeLabelLineHeight,
                          ),
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

  Future<void> _showFinishDialog(BuildContext context, SessionManagerFinished state) async {
    final Widget content;
    if (state.bestScore < state.highscore.score) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreRow(label: "HIGHSCORE by ${state.highscore.username}", value: state.highscore.score),
          const SizedBox(height: 12),
          _ScoreRow(label: "YOUR BEST", value: state.bestScore),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [_ScoreRow(label: "NEW HIGHSCORE", value: state.bestScore)],
      );
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Experiment Complete"),
        content: SizedBox(width: GameLayout.finishDialogWidth, child: content),
        actions: [
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Back to library")),
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(formatScore(value))]);
  }
}

class _GameBar extends StatelessWidget {
  final Protein protein;

  const _GameBar({required this.protein});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: GameLayout.gameBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: GameLayout.gameBarHorizontalPadding),
      child: Row(
        children: [
          Text(protein.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 10),
          Text(protein.pdbId, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          BlocBuilder<ExperimentBloc, ExperimentState>(
            builder: (context, state) {
              if (state is! ExperimentActive) return const SizedBox.shrink();
              return Row(
                children: [
                  Text("ROUND", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text(
                    "${state.turnCount} / ${state.maxTurns}",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: state.turnCount >= state.maxTurns - GameRules.turnWarningMargin
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
          width: GameLayout.dividerWidth,
          child: Center(
            child: Container(width: GameLayout.dividerLineWidth, color: Theme.of(context).dividerColor),
          ),
        ),
      ),
    );
  }
}
