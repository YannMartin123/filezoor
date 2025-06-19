import 'package:flutter/material.dart';

class TransferMode extends StatelessWidget {
  final String transferMode;
  final Function(String) onTransferModeChanged;

  const TransferMode({
    super.key,
    required this.transferMode,
    required this.onTransferModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () => onTransferModeChanged('WiFi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: transferMode == 'WiFi' ? Colors.blue : Colors.grey,
          ),
          child: const Text('WiFi'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => onTransferModeChanged('Bluetooth'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                transferMode == 'Bluetooth' ? Colors.blue : Colors.grey,
          ),
          child: const Text('Bluetooth'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => onTransferModeChanged('Infrarouge'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                transferMode == 'Infrarouge' ? Colors.blue : Colors.grey,
          ),
          child: const Text('Infrarouge'),
        ),
      ],
    );
  }
}
