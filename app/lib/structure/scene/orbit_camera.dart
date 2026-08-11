import "dart:math" as math;
import "dart:ui" show Offset;

import "package:flutter/foundation.dart";
import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart";

import "../../constants.dart";

class OrbitCameraController extends ChangeNotifier {
  OrbitCameraController({
    required Vector3 target,
    required double distance,
    double yaw = CameraLayout.defaultYaw,
    double pitch = CameraLayout.defaultPitch,
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

  double minDistance = CameraLayout.defaultMinDistance;
  double maxDistance = CameraLayout.defaultMaxDistance;

  Vector3 get target => _target;
  double get distance => _distance;

  void orbit(Offset delta, {double sensitivity = CameraLayout.orbitSensitivity}) {
    _yaw -= delta.dx * sensitivity;
    _pitch = (_pitch + delta.dy * sensitivity).clamp(
      CameraLayout.minPitch,
      CameraLayout.maxPitch,
    );
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
    _yaw = CameraLayout.defaultYaw;
    _pitch = CameraLayout.defaultPitch;
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
    fovNear: math.max(
      CameraLayout.fovNearMinimum,
      _distance * CameraLayout.fovNearDistanceFactor,
    ),
    fovFar: _distance * CameraLayout.fovFarDistanceFactor + CameraLayout.fovFarBase,
  );
}
