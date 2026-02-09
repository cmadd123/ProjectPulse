import 'package:cloud_firestore/cloud_firestore.dart';

/// Migration script to fix photos with null created_at timestamps
///
/// This fixes the issue where photos uploaded with FieldValue.serverTimestamp()
/// have null created_at values, causing orderBy queries to exclude them.
///
/// Run this once to update all existing photos to use a valid timestamp.
Future<void> fixPhotoTimestamps() async {
  final firestore = FirebaseFirestore.instance;

  print('Starting photo timestamp migration...');

  try {
    // Get all projects
    final projectsSnapshot = await firestore.collection('projects').get();

    int projectsProcessed = 0;
    int photosFixed = 0;

    for (final projectDoc in projectsSnapshot.docs) {
      print('\nProcessing project: ${projectDoc.id}');

      // Get all updates (photos) for this project
      final updatesSnapshot = await firestore
          .collection('projects')
          .doc(projectDoc.id)
          .collection('updates')
          .get();

      print('  Found ${updatesSnapshot.docs.length} photos');

      for (final updateDoc in updatesSnapshot.docs) {
        final data = updateDoc.data();
        final createdAt = data['created_at'];

        // Check if created_at is null
        if (createdAt == null) {
          print('  Fixing photo ${updateDoc.id} - created_at is null');

          // Update with current timestamp
          await updateDoc.reference.update({
            'created_at': Timestamp.now(),
          });

          photosFixed++;
          print('    ✓ Fixed');
        } else if (createdAt is Timestamp) {
          print('  Photo ${updateDoc.id} - OK (has timestamp)');
        } else {
          print('  Photo ${updateDoc.id} - WARNING: created_at is ${createdAt.runtimeType}');
        }
      }

      projectsProcessed++;
    }

    print('\n======================');
    print('Migration complete!');
    print('Projects processed: $projectsProcessed');
    print('Photos fixed: $photosFixed');
    print('======================\n');

  } catch (e) {
    print('ERROR: Migration failed - $e');
    rethrow;
  }
}

/// Alternative: Fix timestamps for a specific project only
Future<void> fixPhotoTimestampsForProject(String projectId) async {
  final firestore = FirebaseFirestore.instance;

  print('Fixing photo timestamps for project: $projectId');

  try {
    final updatesSnapshot = await firestore
        .collection('projects')
        .doc(projectId)
        .collection('updates')
        .get();

    print('Found ${updatesSnapshot.docs.length} photos');

    int photosFixed = 0;

    for (final updateDoc in updatesSnapshot.docs) {
      final data = updateDoc.data();
      final createdAt = data['created_at'];

      if (createdAt == null) {
        print('Fixing photo ${updateDoc.id}');

        await updateDoc.reference.update({
          'created_at': Timestamp.now(),
        });

        photosFixed++;
      }
    }

    print('✓ Fixed $photosFixed photos');

  } catch (e) {
    print('ERROR: $e');
    rethrow;
  }
}
