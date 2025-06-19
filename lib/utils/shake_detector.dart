import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

class ShakeDetector extends StatefulWidget {
  final VoidCallback onShake;

  const ShakeDetector({super.key, required this.onShake});

  @override
  _ShakeDetectorState createState() => _ShakeDetectorState();
}

class _ShakeDetectorState extends State<ShakeDetector> {
  @override
  void initState() {
    super.initState();
    accelerometerEvents.listen((AccelerometerEvent event) {
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (acceleration > 20) {
        // Seuil pour détecter une secousse
        widget.onShake();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Widget invisible
  }
}
