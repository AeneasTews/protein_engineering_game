import "package:flutter/foundation.dart";
import "package:flutter/services.dart" show KeyEvent;
import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart";

import "../models/molecular_structure.dart";
import "cartoon_builder.dart";
import "orbit_camera.dart";

const double _selectionMarkerRadius = 1.3;
const double _mutationMarkerRadius = 0.9;
final Vector4 _selectionColor = Vector4(0.1, 0.95, 0.95, 1.0);
final Vector4 _mutationColor = Vector4(1.0, 0.55, 0.0, 1.0);

class StructureController extends ChangeNotifier {
  StructureController({
    required this.structure,
    required this.cartoon,
    required this.scene,
    required this.cameraController,
  }) : _residueByPosition = {
         for (final residue in structure.residues) residue.position: residue,
       };

  final MolecularStructure structure;
  final CartoonScene cartoon;
  final Scene scene;
  final OrbitCameraController cameraController;

  final Map<int, Residue> _residueByPosition;

  Residue? _selectedResidue;
  Residue? get selectedResidue => _selectedResidue;

  Node? _selectionMarkerNode;
  final Map<int, Node> _mutationMarkerNodes = {};

  void Function(KeyEvent event)? onKeyEvent;

  void selectResidueAtGymPosition(int position) {
    final Residue? residue = _residueByPosition[position];
    if (residue == null) return;
    _setSelected(residue);
    cameraController.focusOn(residue.alphaCarbon.position);
  }

  void resetCamera() => cameraController.reset();

  void clearSelection() => _setSelected(null);

  void updateMutationMarkers(Iterable<int> positions) {
    for (final node in _mutationMarkerNodes.values) {
      scene.remove(node);
    }
    _mutationMarkerNodes.clear();

    for (final position in positions) {
      final Residue? residue = _residueByPosition[position];
      if (residue == null) continue;
      final Node node = _buildMarkerNode(
        position: residue.alphaCarbon.position,
        radius: _mutationMarkerRadius,
        color: _mutationColor,
      );
      scene.add(node);
      _mutationMarkerNodes[position] = node;
    }
    notifyListeners();
  }

  void handlePick(Residue? residue) => _setSelected(residue);

  void handleKeyEvent(KeyEvent event) => onKeyEvent?.call(event);

  void _setSelected(Residue? residue) {
    if (identical(_selectedResidue, residue)) return;
    _selectedResidue = residue;
    _updateSelectionMarker(residue);
    notifyListeners();
  }

  void _updateSelectionMarker(Residue? residue) {
    final Node? existing = _selectionMarkerNode;
    if (existing != null) {
      scene.remove(existing);
      _selectionMarkerNode = null;
    }

    if (residue == null) return;

    final Node node = _buildMarkerNode(
      position: residue.alphaCarbon.position,
      radius: _selectionMarkerRadius,
      color: _selectionColor,
    );
    scene.add(node);
    _selectionMarkerNode = node;
  }

  Node _buildMarkerNode({
    required Vector3 position,
    required double radius,
    required Vector4 color,
  }) {
    return Node(
      mesh: Mesh(
        SphereGeometry(radius: radius),
        UnlitMaterial()..baseColorFactor = color,
      ),
      localTransform: Matrix4.translation(position),
    );
  }
}
