import "dart:math" as math;
import "dart:ui" show Offset;

import "package:flutter/foundation.dart";
import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart";

const double _minPitch = -math.pi / 2 + 0.05;
const double _maxPitch = math.pi / 2 - 0.05;

class OrbitCameraController extends ChangeNotifier {
  OrbitCameraController({
    required Vector3 target,
    required double distance,
    double yaw = 0.4,
    double pitch = 0.35,
  }) : _target = target,
       _distance = distance,
       _yaw = yaw,
       _pitch = pitch,
       _initialDistance = distance,
       _initialTarget = target.clone();

  Vector3 _target;
  double _distance;
  double _yaw;
  double _pitch;

  final Vector3 _initialTarget;
  final double _initialDistance;

  double minDistance = 0.5;
  double maxDistance = 10000;

  Vector3 get target => _target;
  double get distance => _distance;

  void orbit(Offset delta, {double sensitivity = 0.01}) {
    _yaw -= delta.dx * sensitivity;
    _pitch = (_pitch + delta.dy * sensitivity).clamp(_minPitch, _maxPitch);
    notifyListeners();
  }

  void zoomBy(double factor) {
    _distance = (_distance * factor).clamp(minDistance, maxDistance);
    notifyListeners();
  }

  void focusOn(Vector3 point, {double? distance}) {
    _target = point.clone();
    if (distance != null) _distance = distance.clamp(minDistance, maxDistance);
    notifyListeners();
  }

  void reset() {
    _target = _initialTarget.clone();
    _distance = _initialDistance;
    _yaw = 0.4;
    _pitch = 0.35;
    notifyListeners();
  }

  Vector3 get _eyeOffset {
    final double cosPitch = math.cos(_pitch);
    return Vector3(
      _distance * cosPitch * math.sin(_yaw),
      _distance * math.sin(_pitch),
      _distance * cosPitch * math.cos(_yaw),
    );
  }

  PerspectiveCamera buildCamera() => PerspectiveCamera(
    position: _target + _eyeOffset,
    target: _target,
    fovNear: math.max(0.05, _distance * 0.01),
    fovFar: _distance * 20 + 100,
  );
}
