import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages offline attendance queue in SharedPreferences.
/// Used by both faculty (to queue BLE-received attendance for Firebase sync)
/// and student (to queue attendance when both BLE and Firebase fail).
class OfflineAttendanceQueue {
  static const String _queueKey = 'offline_attendance_queue';

  /// Queue an attendance entry for later sync to Firebase.
  static Future<void> queueAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
    required String studentClass,
    required String subject,
    required String facultyId,
    required String timestamp,
    String? proximityToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_queueKey);
      final List<dynamic> queue =
          existing != null ? json.decode(existing) as List<dynamic> : [];

      queue.add({
        'sessionId': sessionId,
        'studentId': studentId,
        'studentName': studentName,
        'studentClass': studentClass,
        'subject': subject,
        'facultyId': facultyId,
        'timestamp': timestamp,
        'queuedAt': DateTime.now().toIso8601String(),
        if (proximityToken != null) 'proximityToken': proximityToken,
      });

      await prefs.setString(_queueKey, json.encode(queue));
      debugPrint(
          '[OfflineQueue] Queued attendance for $studentId (session: $sessionId). Queue size: ${queue.length}');
    } catch (e) {
      debugPrint('[OfflineQueue] Error queuing attendance: $e');
    }
  }

  /// Get all queued attendance entries.
  static Future<List<Map<String, dynamic>>> getQueuedAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_queueKey);
      if (existing == null || existing.isEmpty) return [];

      final List<dynamic> queue = json.decode(existing) as List<dynamic>;
      return queue.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[OfflineQueue] Error reading queue: $e');
      return [];
    }
  }

  /// Sync all queued attendance entries to Firebase, then clear the queue.
  /// Returns the number of successfully synced entries.
  static Future<int> syncQueuedAttendance() async {
    try {
      final queue = await getQueuedAttendance();
      if (queue.isEmpty) return 0;

      debugPrint('[OfflineQueue] Syncing ${queue.length} queued entries...');

      int synced = 0;
      final List<Map<String, dynamic>> failed = [];

      for (final entry in queue) {
        try {
          final docId = "${entry['sessionId']}_${entry['studentId']}";
          await FirebaseFirestore.instance
              .collection('attendance_responses')
              .doc(docId)
              .set({
            'sessionId': entry['sessionId'],
            'studentId': entry['studentId'],
            'studentName': entry['studentName'],
            'studentClass': entry['studentClass'],
            'subject': entry['subject'],
            'facultyId': entry['facultyId'],
            'responseTime': entry['timestamp'],
            'timestamp': FieldValue.serverTimestamp(),
            'deviceId':
                '${entry['studentId']}_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'present',
            'source': 'offline_sync', // Mark as synced from offline queue
            if (entry['proximityToken'] != null)
              'proximityToken': entry['proximityToken'],
          }, SetOptions(merge: true));
          synced++;
        } catch (e) {
          debugPrint(
              '[OfflineQueue] Failed to sync entry for ${entry['studentId']}: $e');
          failed.add(entry);
        }
      }

      // Keep only failed entries in the queue
      final prefs = await SharedPreferences.getInstance();
      if (failed.isEmpty) {
        await prefs.remove(_queueKey);
      } else {
        await prefs.setString(_queueKey, json.encode(failed));
      }

      debugPrint(
          '[OfflineQueue] Sync complete: $synced synced, ${failed.length} failed');
      return synced;
    } catch (e) {
      debugPrint('[OfflineQueue] Error syncing queue: $e');
      return 0;
    }
  }

  /// Clear the entire queue.
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    debugPrint('[OfflineQueue] Queue cleared');
  }

  /// Get queue size without loading all data.
  static Future<int> getQueueSize() async {
    final queue = await getQueuedAttendance();
    return queue.length;
  }
}
