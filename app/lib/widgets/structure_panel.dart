import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_all/webview_all.dart';
import '../../blocs/experiment/experiment_bloc.dart';
import '../presentation/molstar_controller.dart';

// Temporary placeholder in StructurePanel
class StructurePanel extends StatelessWidget {
  final String? pdbData;
  const StructurePanel({super.key, required this.pdbData});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.biotech, size: 50),
            const SizedBox(height: 16),
            Text(
              pdbData != null
                  ? '3D structure loaded (${pdbData!.length ~/ 1024} KB)'
                  : 'Loading structure...',
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

class StructurePanelDev extends StatefulWidget {
  final String? pdbData;

  const StructurePanelDev({super.key, required this.pdbData});

  @override
  State<StructurePanelDev> createState() => _StructurePanelState();
}

class _StructurePanelState extends State<StructurePanelDev> {
  late final MolstarController _molstar;
  int? _selectedPosition;
  bool _structureLoaded = false;

  @override
  void initState() {
    super.initState();
    _molstar = MolstarController();

    _molstar.onResidueSelected = (position) {
      if (!mounted) return;
      setState(() {
        _selectedPosition = _selectedPosition == position ? null : position;
      });
      if (_selectedPosition != null) {
        _molstar.focusResidue(_selectedPosition!);
      } else {
        _molstar.clearHighlights();
      }
    };
  }

  @override
  void didUpdateWidget(StructurePanelDev oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_structureLoaded && widget.pdbData != null) {
      _structureLoaded = true;
      _molstar.loadStructure(widget.pdbData!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _molstar.webViewController),
        BlocListener<ExperimentBloc, ExperimentState>(
          listenWhen: (prev, next) {
            if (prev is ExperimentActive && next is ExperimentActive) {
              return prev.currentMutations != next.currentMutations;
            }
            return next is ExperimentInitial;
          },
          listener: (context, state) async {
            if (state is ExperimentActive) {
              await _molstar.highlightResidues(state.currentMutations);
              if (_selectedPosition != null) {
                final stillMutated = state.currentMutations
                    .any((m) => m.$1 == _selectedPosition);
                if (!stillMutated) {
                  setState(() => _selectedPosition = null);
                  await _molstar.clearHighlights();
                }
              }
            }
            if (state is ExperimentInitial) {
              await _molstar.clearHighlights();
              setState(() => _selectedPosition = null);
            }
          },
          child: const SizedBox.shrink(),
        ),

        if (widget.pdbData == null)
          Container(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Fetching structure...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),

        if (_selectedPosition != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(),
              ),
              child: Text(
                'Residue $_selectedPosition',
                style: Theme.of(context).textTheme.bodyLarge
              ),
            ),
          ),
      ],
    );
  }
}