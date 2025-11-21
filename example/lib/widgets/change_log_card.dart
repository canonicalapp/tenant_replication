import 'package:flutter/material.dart';

/// Change log entry card widget
class ChangeLogCard extends StatelessWidget {
  final Map<String, Object?> log;

  const ChangeLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final action = (log['action'] as String?) ?? 'unknown';
    final txid = log['txid'];
    final tableName = log['table_name'];
    final recordPk = log['record_pk'];

    IconData icon;
    Color color;
    String label;

    switch (action) {
      case 'insert':
        icon = Icons.add_circle;
        color = Colors.green;
        label = 'INSERT';
        break;
      case 'delete':
        icon = Icons.remove_circle;
        color = Colors.red;
        label = 'DELETE';
        break;
      case 'update':
        icon = Icons.edit;
        color = Colors.orange;
        label = 'UPDATE';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        label = action.toUpperCase();
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('$tableName #$recordPk'),
        subtitle: Text(
          'TXID: $txid\nAction: $label',
          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

