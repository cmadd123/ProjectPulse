import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService._();

  Future<void> initialize() async {
    // Check initial state
    final results = await Connectivity().checkConnectivity();
    isOnline.value = !results.contains(ConnectivityResult.none);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = !results.contains(ConnectivityResult.none);
    });
  }

  /// Show a snackbar if offline to let user know their write will sync later.
  /// Call after any Firestore write (milestone approval, change order, chat, etc.)
  static void showOfflineWriteFeedback(BuildContext context) {
    if (!_instance.isOnline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Saved — will sync when back online'),
            ],
          ),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
