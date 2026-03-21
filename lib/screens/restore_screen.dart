import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../providers/ftracker_provider.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  List<File> _backups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final backups = await BackupService.getBackups();
    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _backups.isEmpty
              ? const Center(child: Text('No backups found.'))
              : ListView.builder(
                  itemCount: _backups.length,
                  itemBuilder: (context, index) {
                    final file = _backups[index];
                    final date = file.lastModifiedSync();
                    final fileName = file.path.split('/').last;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(fileName),
                        subtitle: Text(
                            'Date: ${DateFormat.yMMMd().add_jm().format(date)}'),
                        trailing: const Icon(Icons.restore),
                        onTap: () => _confirmRestore(file),
                      ),
                    );
                  },
                ),
    );
  }

  void _confirmRestore(File file) {
    final parentContext = context;
    final ftrackerProvider =
        Provider.of<FtrackerProvider>(parentContext, listen: false);
    final messenger = ScaffoldMessenger.of(parentContext);
    final navigator = Navigator.of(parentContext);
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text(
            'Are you sure you want to restore this backup? Current data will be overwritten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ftrackerProvider.restoreBackup(file);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Data restored successfully!')),
              );
              navigator.pop();
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
