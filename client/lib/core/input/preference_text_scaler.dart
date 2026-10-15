import 'package:flutter/painting.dart';

/// Retains the operating system's (possibly nonlinear) accessibility scaling.
class PreferenceTextScaler extends TextScaler {
  const PreferenceTextScaler(this.system, this.preference);
  final TextScaler system;
  final double preference;

  @override
  double scale(double fontSize) => system.scale(fontSize) * preference;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is PreferenceTextScaler &&
      other.system == system &&
      other.preference == preference;
  @override
  int get hashCode => Object.hash(system, preference);
}
