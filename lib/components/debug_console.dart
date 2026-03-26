import 'package:flutter/material.dart';
import 'dart:collection';

/// In-app debug console for viewing logs without USB connection
class DebugConsole {
  static final DebugConsole _instance = DebugConsole._internal();
  factory DebugConsole() => _instance;
  DebugConsole._internal();

  final _logs = ListQueue<String>();
  final int _maxLogs = 500;
  final List<VoidCallback> _listeners = [];

  void log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);

    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }

    // Notify listeners
    for (var listener in _listeners) {
      listener();
    }

    // Also print to console for USB debugging
    print(logEntry);
  }

  List<String> get logs => _logs.toList();

  void clear() {
    _logs.clear();
    for (var listener in _listeners) {
      listener();
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

/// Floating debug button that opens the console
class DebugConsoleButton extends StatelessWidget {
  const DebugConsoleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      heroTag: 'debug_console',
      backgroundColor: Colors.purple.withOpacity(0.7),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.black87,
          builder: (context) => const DebugConsoleScreen(),
        );
      },
      child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
    );
  }
}

/// Full-screen debug console
class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    DebugConsole().addListener(_onLogsUpdated);
  }

  @override
  void dispose() {
    DebugConsole().removeListener(_onLogsUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsUpdated() {
    if (mounted) {
      setState(() {});
      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = DebugConsole().logs;
    final filteredLogs = _filter.isEmpty
        ? logs
        : logs.where((log) => log.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.purple, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Debug Console',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Filter logs...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _autoScroll ? Icons.arrow_downward : Icons.arrow_downward_outlined,
                  color: _autoScroll ? Colors.green : Colors.grey,
                ),
                tooltip: 'Auto-scroll',
                onPressed: () {
                  setState(() {
                    _autoScroll = !_autoScroll;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Clear logs',
                onPressed: () {
                  DebugConsole().clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logs cleared'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', logs.length.toString(), Colors.blue),
                _buildStat('Filtered', filteredLogs.length.toString(), Colors.purple),
                _buildStat('🔍', filteredLogs.where((l) => l.contains('🔍')).length.toString(), Colors.cyan),
                _buildStat('✅', filteredLogs.where((l) => l.contains('✅')).length.toString(), Colors.green),
                _buildStat('❌', filteredLogs.where((l) => l.contains('❌')).length.toString(), Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Logs
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        _filter.isEmpty ? 'No logs yet' : 'No logs match filter',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return _buildLogEntry(log);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(String log) {
    Color color = Colors.grey[400]!;
    if (log.contains('✅')) {
      color = Colors.green;
    } else if (log.contains('❌')) {
      color = Colors.red;
    } else if (log.contains('🔍')) {
      color = Colors.cyan;
    } else if (log.contains('⏳')) {
      color = Colors.orange;
    } else if (log.contains('ℹ️')) {
      color = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectableText(
        log,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: color,
          height: 1.4,
        ),
      ),
    );
  }
}
