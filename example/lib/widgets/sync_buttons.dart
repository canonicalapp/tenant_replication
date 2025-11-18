import 'package:flutter/material.dart';

/// Sync operation buttons widget
class SyncButtons extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onSyncToServer;
  final VoidCallback onLoadFromServer;

  const SyncButtons({
    super.key,
    required this.isSyncing,
    required this.onSyncToServer,
    required this.onLoadFromServer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isSyncing ? null : onSyncToServer,
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(isSyncing ? 'Syncing...' : 'Sync to Server'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isSyncing ? null : onLoadFromServer,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Load from Server'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

