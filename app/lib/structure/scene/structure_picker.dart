import "dart:ui" show Offset, Size;

import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart" show Ray;

import "../models/backbone_segment.dart";
import "../models/molecular_structure.dart";
import "cartoon_builder.dart";

Residue? pickResidueAt({
  required Offset screenPosition,
  required Size viewSize,
  required Camera camera,
  required Scene scene,
  required CartoonScene cartoon,
}) {
  final Ray ray = camera.screenPointToRay(screenPosition, viewSize);
  final SceneRaycastHit? hit = raycastNode(scene.root, ray, where: (node) => cartoon.segmentForNode.containsKey(node));
  if (hit == null) return null;

  final BackboneSegment? segment = cartoon.segmentForNode[hit.node];
  if (segment == null) return null;

  Residue? closest;
  double closestDistanceSquared = double.infinity;
  for (final residue in segment.residues) {
    final double distanceSquared = residue.alphaCarbon.position.distanceToSquared(hit.worldPoint);
    if (distanceSquared < closestDistanceSquared) {
      closestDistanceSquared = distanceSquared;
      closest = residue;
    }
  }
  return closest;
}
