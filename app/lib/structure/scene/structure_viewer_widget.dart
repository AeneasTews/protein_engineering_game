import "package:flutter/gestures.dart";
import "package:flutter/widgets.dart";
import "package:flutter_scene/scene.dart";

import "../../constants.dart";
import "../models/molecular_structure.dart";
import "orbit_camera.dart";
import "structure_controller.dart";
import "structure_picker.dart";

class StructureViewerWidget extends StatefulWidget {
  const StructureViewerWidget({super.key, required this.controller, this.onResidueTap});

  final StructureController controller;

  final void Function(Residue residue, Offset globalPosition)? onResidueTap;

  @override
  State<StructureViewerWidget> createState() => _StructureViewerWidgetState();
}

class _StructureViewerWidgetState extends State<StructureViewerWidget> {
  final FocusNode _focusNode = FocusNode(debugLabel: "StructureViewer");

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StructureController controller = widget.controller;
    final OrbitCameraController cameraController = controller.cameraController;

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size viewSize = constraints.biggest;
        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            controller.handleKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final double factor = 1 + event.scrollDelta.dy * CameraLayout.scrollZoomSensitivity;
                cameraController.zoomBy(factor.clamp(CameraLayout.zoomFactorMin, CameraLayout.zoomFactorMax));
              }
            },
            child: GestureDetector(
              onPanUpdate: (details) => cameraController.orbit(details.delta),
              onTapUp: (details) {
                _focusNode.requestFocus();
                final Residue? residue = pickResidueAt(
                  screenPosition: details.localPosition,
                  viewSize: viewSize,
                  camera: cameraController.buildCamera(),
                  scene: controller.scene,
                  cartoon: controller.cartoon,
                );
                controller.handlePick(residue);
                if (residue != null) {
                  widget.onResidueTap?.call(residue, details.globalPosition);
                }
              },
              child: SceneView(controller.scene, cameraBuilder: (elapsed) => cameraController.buildCamera()),
            ),
          ),
        );
      },
    );
  }
}
