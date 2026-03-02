import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await FirebaseAuth.instance.signOut();
  }
}
