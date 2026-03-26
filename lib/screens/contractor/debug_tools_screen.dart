import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/debug_logger.dart';

/// Debug screen to view notification logs in real-time
class DebugToolsScreen extends StatefulWidget {
  const DebugToolsScreen({super.key});

  @override
  State<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

class _DebugToolsScreenState extends State<DebugToolsScreen> {
  List<String>? _fcmTokens;
  bool _loadingTokens = true;

  @override
  void initState() {
    super.initState();
    DebugLogger.addListener(_onLogsUpdated);
    _loadFCMTokens();
  }

  @override
  void dispose() {
    DebugLogger.removeListener(_onLogsUpdated);
    super.dispose();
  }

  void _onLogsUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFCMTokens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loadingTokens = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final tokens = userDoc.data()?['fcm_tokens'] as List<dynamic>?;
      setState(() {
        _fcmTokens = tokens?.cast<String>();
        _loadingTokens = false;
      });
    } catch (e) {
      setState(() => _loadingTokens = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = DebugLogger.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              DebugLogger.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared')),
              );
            },
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FCM Token Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_fcmTokens?.isNotEmpty ?? false)
                    ? Colors.green[50]
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_fcmTokens?.isNotEmpty ?? false)
                      ? Colors.green[200]!
                      : Colors.orange[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        (_fcmTokens?.isNotEmpty ?? false)
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: (_fcmTokens?.isNotEmpty ?? false)
                            ? Colors.green[700]
                            : Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (_fcmTokens?.isNotEmpty ?? false)
                            ? 'Push Notifications: Enabled'
                            : 'Push Notifications: Not Ready',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingTokens)
                    const Text('Loading FCM token status...')
                  else if (_fcmTokens == null || _fcmTokens!.isEmpty)
                    const Text(
                      'No FCM tokens found. Notifications will not work.\n\n'
                      'Fix: Close and reopen the app to register device.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    )
                  else ...[
                    Text(
                      'Device registered: ${_fcmTokens!.length} token(s)',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: _fcmTokens!.first),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('FCM token copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _fcmTokens!.first.substring(0, 40) + '...',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const Icon(Icons.copy, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'How to use this',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Create a change order\n'
                    '2. Watch the logs appear below in real-time\n'
                    '3. Logs show exactly where the notification process stops\n'
                    '4. Screenshot the logs and share them',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Logs (${logs.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_empty,
                                size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text(
                              'Waiting for notification events...',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a change order to see logs',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        reverse: true, // Show newest at bottom
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[logs.length - 1 - index];
                          final isError = log.contains('❌');
                          final isSuccess = log.contains('✅');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.4,
                                color: isError
                                    ? Colors.red[300]
                                    : isSuccess
                                        ? Colors.green[300]
                                        : Colors.grey[300],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
