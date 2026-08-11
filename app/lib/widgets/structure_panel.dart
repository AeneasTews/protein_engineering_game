import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../structure/scene/structure_controller.dart";
import "../structure/scene/structure_viewer_widget.dart";

class StructurePanel extends StatelessWidget {
  final StructureController? controller;
  final Object? loadError;
  final void Function(int position, double x, double y)? onResidueClick;

  const StructurePanel({
    super.key,
    this.controller,
    this.loadError,
    this.onResidueClick,
  });

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
        final controller = this.controller;
        if (controller == null) return;
        if (state is ExperimentActive) {
          controller.updateMutationMarkers(
            state.currentMutations.map((m) => m.$1),
          );
        }
        if (state is ExperimentInitial) {
          controller.updateMutationMarkers(const []);
        }
      },
      child: _content(),
    );
  }

  Widget _content() {
    final controller = this.controller;
    if (loadError != null) {
      return Center(child: Text("Failed to load structure: $loadError"));
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StructureViewerWidget(
      controller: controller,
      onResidueTap: (residue, globalPosition) => onResidueClick?.call(
        residue.position,
        globalPosition.dx,
        globalPosition.dy,
      ),
    );
  }
}
