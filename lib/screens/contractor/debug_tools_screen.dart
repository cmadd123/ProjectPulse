import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug tools screen for fixing data issues
class DebugToolsScreen extends StatefulWidget {
  const DebugToolsScreen({super.key});

  @override
  State<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

class _DebugToolsScreenState extends State<DebugToolsScreen> {
  bool _isFixingTimestamps = false;
  String _migrationLog = '';

  Future<void> _fixPhotoTimestamps() async {
    setState(() {
      _isFixingTimestamps = true;
      _migrationLog = 'Starting migration...\n';
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Get all projects
      final projectsSnapshot = await firestore.collection('projects').get();

      setState(() {
        _migrationLog += 'Found ${projectsSnapshot.docs.length} projects\n\n';
      });

      int projectsProcessed = 0;
      int photosFixed = 0;

      for (final projectDoc in projectsSnapshot.docs) {
        setState(() {
          _migrationLog += 'Project: ${projectDoc.id}\n';
        });

        // Get all updates (photos) for this project
        final updatesSnapshot = await firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('updates')
            .get();

        setState(() {
          _migrationLog += '  Photos: ${updatesSnapshot.docs.length}\n';
        });

        for (final updateDoc in updatesSnapshot.docs) {
          final data = updateDoc.data();
          final createdAt = data['created_at'];

          // Check if created_at is null
          if (createdAt == null) {
            setState(() {
              _migrationLog += '  ✗ ${updateDoc.id} - null timestamp, fixing...\n';
            });

            // Update with current timestamp
            await updateDoc.reference.update({
              'created_at': Timestamp.now(),
            });

            photosFixed++;

            setState(() {
              _migrationLog += '    ✓ Fixed!\n';
            });
          } else if (createdAt is Timestamp) {
            setState(() {
              _migrationLog += '  ✓ ${updateDoc.id} - OK\n';
            });
          }
        }

        projectsProcessed++;
        setState(() {
          _migrationLog += '\n';
        });
      }

      setState(() {
        _migrationLog += '======================\n';
        _migrationLog += 'Migration complete!\n';
        _migrationLog += 'Projects: $projectsProcessed\n';
        _migrationLog += 'Photos fixed: $photosFixed\n';
        _migrationLog += '======================\n';
        _isFixingTimestamps = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fixed $photosFixed photos!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _migrationLog += '\nERROR: $e\n';
        _isFixingTimestamps = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tools'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Photo Timestamp Migration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fixes photos with null created_at timestamps (caused by server timestamp delays)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isFixingTimestamps ? null : _fixPhotoTimestamps,
                icon: _isFixingTimestamps
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.build_circle),
                label: Text(
                  _isFixingTimestamps ? 'Fixing...' : 'Fix Photo Timestamps',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Migration Log',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _migrationLog.isEmpty ? 'No migration run yet' : _migrationLog,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
