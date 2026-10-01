import "package:bio_flutter/protein_viewer.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../constants.dart";
import "../data/models/protein_structure.dart";

/// The 3D cartoon (bio_flutter's [ProteinViewer]), speaking in game sequence positions.
///
/// Pending mutations are highlighted, [selectedPosition] is shown as the selection, and tapping
/// a residue reports its position together with the pointer location for the amino acid picker.
class StructurePanel extends StatefulWidget {
  final ProteinStructure? structure;
  final Object? loadError;
  final ProteinViewerController controller;
  final int? selectedPosition;
  final ValueChanged<int?> onSelectedPositionChanged;
  final void Function(int position, double x, double y)? onResidueClick;

  const StructurePanel({
    super.key,
    required this.structure,
    required this.loadError,
    required this.controller,
    required this.selectedPosition,
    required this.onSelectedPositionChanged,
    this.onResidueClick,
  });

  @override
  State<StructurePanel> createState() => _StructurePanelState();
}

class _StructurePanelState extends State<StructurePanel> {
  // ProteinViewer reports which residue was tapped but not where, so the pointer is tracked here.
  Offset _lastPointerDown = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final structure = widget.structure;
    if (widget.loadError != null) {
      return Center(child: Text("Failed to load structure: ${widget.loadError}"));
    }
    if (structure == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedKey = widget.selectedPosition == null ? null : structure.keyAt(widget.selectedPosition!);

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (event) => _lastPointerDown = event.position,
            child: BlocBuilder<ExperimentBloc, ExperimentState>(
              buildWhen: (prev, next) =>
                  prev is! ExperimentActive ||
                  next is! ExperimentActive ||
                  prev.currentMutations != next.currentMutations,
              builder: (context, state) => ProteinViewer(
                structure: structure.structure,
                controller: widget.controller,
                style: StructureStyle.cartoon,
                selectedResidues: {?selectedKey},
                highlights: _mutationHighlights(structure, state),
                onSelectionChanged: (keys) => widget.onSelectedPositionChanged(_pickPosition(structure, keys)),
                onResidueTap: (hit) {
                  final position = hit == null ? null : structure.positionOf(hit.key);
                  if (position == null) return;
                  widget.onResidueClick?.call(position, _lastPointerDown.dx, _lastPointerDown.dy);
                },
                errorBuilder: (_, error) => Center(child: Text("The structure viewer failed: $error")),
              ),
            ),
          ),
        ),
        Positioned(
          right: StructureViewerLayout.recenterButtonMargin,
          bottom: StructureViewerLayout.recenterButtonMargin,
          child: FloatingActionButton.small(
            onPressed: widget.controller.resetCamera,
            tooltip: "Recenter camera",
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }

  Map<ResidueKey, Color> _mutationHighlights(ProteinStructure structure, ExperimentState state) {
    if (state is! ExperimentActive) return const {};
    return {
      for (final (position, _) in state.currentMutations) ?structure.keyAt(position): StructureStyle.mutationColor,
    };
  }

  // The game keeps a single selected residue; the viewer may propose several (shift-click),
  // in which case the one that was just added wins.
  int? _pickPosition(ProteinStructure structure, Set<ResidueKey> keys) {
    final current = widget.selectedPosition == null ? null : structure.keyAt(widget.selectedPosition!);
    final added = keys.where((k) => k != current);
    final key = added.isNotEmpty ? added.last : (keys.isEmpty ? null : keys.first);
    return key == null ? null : structure.positionOf(key);
  }
}
