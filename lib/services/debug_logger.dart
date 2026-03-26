import 'package:flutter/foundation.dart';

/// In-app debug logger for notification debugging
class DebugLogger {
  static final List<String> _logs = [];
  static final List<Function()> _listeners = [];

  /// Add a log entry
  static void log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    debugPrint(logEntry);
    _notifyListeners();

    // Keep only last 100 entries
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
  }

  /// Get all logs
  static List<String> getLogs() => List.unmodifiable(_logs);

  /// Clear all logs
  static void clear() {
    _logs.clear();
    _notifyListeners();
  }

  /// Add a listener for log updates
  static void addListener(Function() listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  static void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
