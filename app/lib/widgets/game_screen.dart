import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart" as vm;
import "../blocs/experiment/experiment_bloc.dart";
import "../blocs/protein_library/protein_library_bloc.dart";
import "../blocs/session_manager/session_manager_bloc.dart";
import "../constants.dart";
import "../data/models/protein.dart";
import "../data/repositories/protein_repository.dart";
import "../structure/models/molecular_structure.dart";
import "../structure/scene/cartoon_builder.dart";
import "../structure/scene/orbit_camera.dart";
import "../structure/scene/structure_controller.dart";
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
  StructureController? _structureController;
  Object? _structureLoadError;

  double _leftFraction = GameLayout.initialLeftFraction;
  double _midFraction = GameLayout.initialMidFraction;

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  @override
  void dispose() {
    _structureController?.cameraController.dispose();
    _structureController?.dispose();
    super.dispose();
  }

  Future<void> _loadStructure() async {
    try {
      final structureFuture = context.read<ProteinRepository>().getStructure(
        widget.protein.pdbId,
      );
      await Scene.initializeStaticResources();
      final structure = await structureFuture;
      if (!mounted) return;
      _onStructureLoaded(structure);
    } catch (e) {
      if (!mounted) return;
      setState(() => _structureLoadError = e);
    }
  }

  void _onStructureLoaded(MolecularStructure structure) {
    final CartoonScene cartoon = buildCartoonScene(structure);
    final Scene scene = Scene()
      ..directionalLight = DirectionalLight(
        direction: SceneLighting.directionalLightDirection,
      );
    for (final node in cartoon.nodes) {
      scene.add(node);
    }

    final (vm.Vector3 center, double radius) = _boundingSphere(structure);
    final OrbitCameraController cameraController = OrbitCameraController(
      target: center,
      distance: radius * CameraLayout.initialDistanceFactor,
    )..minDistance = radius * CameraLayout.minDistanceFactor;

    final StructureController controller = StructureController(
      structure: structure,
      cartoon: cartoon,
      scene: scene,
      cameraController: cameraController,
    );

    final experimentState = context.read<ExperimentBloc>().state;
    if (experimentState is ExperimentActive) {
      controller.updateMutationMarkers(
        experimentState.currentMutations.map((m) => m.$1),
      );
    }

    setState(() => _structureController = controller);
  }

  (vm.Vector3, double) _boundingSphere(MolecularStructure structure) {
    final List<vm.Vector3> positions = [
      for (final residue in structure.residues) residue.alphaCarbon.position,
    ];
    if (positions.isEmpty) {
      return (vm.Vector3.zero(), CameraLayout.fallbackBoundingRadius);
    }

    final vm.Vector3 center = vm.Vector3.zero();
    for (final position in positions) {
      center.add(position);
    }
    center.scale(1.0 / positions.length);

    double radius = 0.0;
    for (final position in positions) {
      final double distance = position.distanceTo(center);
      if (distance > radius) radius = distance;
    }
    return (center, radius == 0.0 ? CameraLayout.fallbackBoundingRadius : radius);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ExperimentBloc, ExperimentState>(
          listenWhen: (_, next) => next is ExperimentFinished,
          listener: (context, state) {
            if (state is! ExperimentFinished) return;
            context.read<SessionManagerBloc>().add(
              SessionManagerFinish(score: state.bestScore),
            );
          },
        ),
        BlocListener<SessionManagerBloc, SessionManagerState>(
          listenWhen: (_, next) => next is SessionManagerFinished,
          listener: (context, state) async {
            if (state is! SessionManagerFinished) return;
            context.read<ProteinLibraryBloc>().add(
              HighscoreUpdated(pdbId: state.pdbId, highscore: state.highscore),
            );

            await _showFinishDialog(context, state);

            if (!context.mounted) return;
            context.read<ExperimentBloc>().add(ExperimentClose());
            context.read<SessionManagerBloc>().add(SessionManagerClose());
            Navigator.of(context).pop();
          },
        ),
      ],
      child: Scaffold(
        body: Column(
          children: [
            _GameBar(protein: widget.protein),
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
                          onResidueTap: (position) => _structureController
                              ?.selectResidueAtGymPosition(position),
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
                          controller: _structureController,
                          loadError: _structureLoadError,
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
                      experimentBloc.add(
                        MutationChange(
                          position: seqPosition,
                          aminoAcid: aminoAcid,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UiLayout.cardBorderRadius),
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

  Future<void> _showFinishDialog(
    BuildContext context,
    SessionManagerFinished state,
  ) async {
    final Widget content;
    if (state.bestScore < state.highscore.score) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreRow(
            label: "HIGHSCORE by ${state.highscore.username}",
            value: state.highscore.score,
          ),
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
        Text(value.toStringAsFixed(GameRules.scoreDecimalPlaces)),
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
      height: GameLayout.gameBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: GameLayout.gameBarHorizontalPadding,
      ),
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
                    "${state.turnCount} / ${GameRules.maxTurns}",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: state.turnCount >= GameRules.turnWarningThreshold
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
            child: Container(
              width: GameLayout.dividerLineWidth,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
