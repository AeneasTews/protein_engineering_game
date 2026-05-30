import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/experiment/experiment_bloc.dart';
import '../molstar/molstar_controller.dart';
import '../molstar/molstar_view.dart';

class StructurePanel extends StatefulWidget {
  final String pdbId;

  const StructurePanel({super.key, required this.pdbId});

  @override
  State<StructurePanel> createState() => _StructurePanelState();
}

class _StructurePanelState extends State<StructurePanel> {
  final molstarController = MolstarController();
  String _lastEvent = "-";

  @override
  void initState() {
    super.initState();
    molstarController.onResidueEvent = (chain, residue, eventType) {
      setState(() {
        _lastEvent = eventType == "clear" ? "-" : "$eventType chain=$chain residue=$residue";
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExperimentBloc, ExperimentState>(
      listener: (context, state) {
        if (state is! ExperimentActive) return;
        print(state.currentMutations);

        if (state.currentMutations.isEmpty) {
          molstarController.clearHighlight();
          return;
        }

        for (final mutation in state.currentMutations) {
          molstarController.highlightResidue("A", mutation.$1);
        }
      },
      child: Container(
        child: Column(
            children: [
              const Text("Structure Viewer"),
              Text("Last event: $_lastEvent"),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () {
                    molstarController.loadPdb(widget.pdbId);
                  },
                  child: const Text("Load Structure")
              ),
              TextButton(
                  onPressed: () {
                    molstarController.highlightResidue("A", 53);
                  },
                  child: const Text("Highight A 53")
              ),
              TextButton(
                  onPressed: () {
                    molstarController.clearHighlight();
                  },
                  child: const Text("Clear Highlights")
              ),
              Expanded(child: MolstarView(controller: molstarController, pdbId: widget.pdbId)),
            ]
        ),
      )
    );
  }
}