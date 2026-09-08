import 'package:flutter/services.dart';

/// Browse orientations aligned with iOS Info.plist (no upside-down).
const List<DeviceOrientation> kBrowseOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Forced while the player is open.
const List<DeviceOrientation> kPlayerOrientations = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];
