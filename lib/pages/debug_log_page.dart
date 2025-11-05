// ============================================
// lib/pages/debug_log_page.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugLogPage extends StatelessWidget {
  final List<String> logs;

  const DebugLogPage({super.key, required this.logs});

  void _copyToClipboard(BuildContext context) {
    final allLogs = logs.join('\n');
    Clipboard.setData(ClipboardData(text: allLogs));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Logs copied to clipboard! ✓')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Logs'),
        actions: [
          IconButton(
            icon: Icon(Icons.copy),
            onPressed: () => _copyToClipboard(context),
            tooltip: 'Copy all logs',
          ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No logs yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start listening to see detected sounds',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header info
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  color: Colors.grey[900],
                  child: Text(
                    'Total logs: ${logs.length}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),

                // Logs list
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isWaterDetected = log.contains('💧');

                      return Container(
                        margin: EdgeInsets.only(bottom: 4),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isWaterDetected
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey[900],
                          borderRadius: BorderRadius.circular(4),
                          border: isWaterDetected
                              ? Border.all(color: Colors.blue, width: 1)
                              : null,
                        ),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isWaterDetected
                                ? Colors.blue
                                : Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: logs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _copyToClipboard(context),
              icon: Icon(Icons.copy),
              label: Text('Copy All'),
              backgroundColor: Color(0xFFB71C1C),
            )
          : null,
    );
  }
}
