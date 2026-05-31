import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../molstar/molstar_controller.dart";
import "../molstar/molstar_view.dart";

class StructurePanel extends StatefulWidget {
  final String pdbId;
  final String wildtypeSequence;
  final MolstarController controller;

  final void Function(int position, double x, double y)? onResidueClick;

  const StructurePanel({
    super.key,
    required this.pdbId,
    required this.wildtypeSequence,
    required this.controller,
    this.onResidueClick,
  });

  @override
  State<StructurePanel> createState() => _StructurePanelState();
}

class _StructurePanelState extends State<StructurePanel> {

  @override
  void initState() {
    super.initState();

    widget.controller.onResidueEvent = (seqPosition, eventType, x, y) {
      //debugPrint("[StructurePanel] Residue clicked: seqPosition=$seqPosition eventType=$eventType");
      if (eventType == "click") {
        widget.onResidueClick?.call(seqPosition, x, y);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExperimentBloc, ExperimentState>(
      listenWhen: (prev, next) {
        if (prev is ExperimentActive && next is ExperimentActive) {
          return prev.currentMutations != next.currentMutations;
        }
        return next is ExperimentInitial;
      },
      listener: (context, state) {
        if (state is ExperimentActive) {
          if (state.currentMutations.isEmpty) {
            widget.controller.clearHighlight();
          } else {
            widget.controller.updateMutationColors(
              state.currentMutations.map((m) => m.$1).toList(),
            );
          }
        }
        if (state is ExperimentInitial) {
          widget.controller.clearHighlight();
        }
      },
      child: Column(
        children: [
          /*Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Text("Last event: ", style: TextStyle(fontSize: 12)),
                Text(_lastEvent, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),*/
          Expanded(
            child: MolstarView(
              controller: widget.controller,
              pdbId: widget.pdbId,
              wildtypeSequence: widget.wildtypeSequence,
            ),
          ),
        ],
      ),
    );
  }
}