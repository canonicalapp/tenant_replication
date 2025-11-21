import 'package:flutter/material.dart';
import '../database.dart';

/// User card widget with actions menu
class UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onUpdate;
  final VoidCallback onSoftDelete;
  final VoidCallback onHardDelete;

  const UserCard({
    super.key,
    required this.user,
    required this.onUpdate,
    required this.onSoftDelete,
    required this.onHardDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = user.mtdsDeletedTxid != null;

    return Card(
      color: isDeleted ? Colors.red.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDeleted ? Colors.red : Colors.blue,
          child: Text(
            user.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user.name,
          style: TextStyle(
            decoration: isDeleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text(
              'TXID: ${user.mtdsLastUpdatedTxid}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
            if (isDeleted)
              Text(
                'Deleted TXID: ${user.mtdsDeletedTxid}',
                style: const TextStyle(fontSize: 10, color: Colors.red),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  onTap: () => Future.delayed(Duration.zero, onUpdate),
                  child: const Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Update'),
                    ],
                  ),
                ),
                if (!isDeleted)
                  PopupMenuItem(
                    onTap: () => Future.delayed(Duration.zero, onSoftDelete),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Soft Delete'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  onTap: () => Future.delayed(Duration.zero, onHardDelete),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_forever, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hard Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }
}
