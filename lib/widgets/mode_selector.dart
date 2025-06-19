import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  final String mode;
  final Function(String) onModeChanged;

  const ModeSelector({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () => onModeChanged('Sender'),
          style: ElevatedButton.styleFrom(
            backgroundColor: mode == 'Sender' ? Colors.blue : Colors.grey,
          ),
          child: const Text('Sender'),
        ),
        const SizedBox(width: 20),
        ElevatedButton(
          onPressed: () => onModeChanged('Receiver'),
          style: ElevatedButton.styleFrom(
            backgroundColor: mode == 'Receiver' ? Colors.blue : Colors.grey,
          ),
          child: const Text('Receiver'),
        ),
      ],
    );
  }
}
