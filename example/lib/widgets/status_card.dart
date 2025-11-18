import 'package:flutter/material.dart';

/// Status message card widget
class StatusCard extends StatelessWidget {
  final String message;

  const StatusCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isSuccess = message.startsWith('✅');
    final isError = message.startsWith('❌');

    Color backgroundColor;
    IconData icon;
    Color iconColor;

    if (isSuccess) {
      backgroundColor = Colors.green.shade50;
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (isError) {
      backgroundColor = Colors.red.shade50;
      icon = Icons.error;
      iconColor = Colors.red;
    } else {
      backgroundColor = Colors.blue.shade50;
      icon = Icons.info;
      iconColor = Colors.blue;
    }

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

