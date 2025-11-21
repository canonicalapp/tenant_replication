import 'package:flutter/material.dart';

/// Trigger card widget
class TriggerCard extends StatelessWidget {
  final Map<String, dynamic> trigger;

  const TriggerCard({super.key, required this.trigger});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.flash_on, color: Colors.purple),
        title: Text(trigger['name'] ?? 'Unknown'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              trigger['sql'] ?? 'No SQL',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

