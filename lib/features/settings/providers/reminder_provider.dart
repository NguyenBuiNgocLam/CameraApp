import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  ReminderProvider({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService =
           notificationService ?? NotificationService.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  bool isLoading = false;
  bool dailyReminderEnabled = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 20, minute: 0);
  String? errorMessage;
  String? successMessage;

  Future<void> loadReminderSettings() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      errorMessage = 'User is not authenticated';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final snapshot = await _settingsRef(uid).get();
      final data = snapshot.data();
      dailyReminderEnabled = data?['dailyReminderEnabled'] as bool? ?? false;
      reminderTime = TimeOfDay(
        hour: (data?['dailyReminderHour'] as num?)?.toInt() ?? 20,
        minute: (data?['dailyReminderMinute'] as num?)?.toInt() ?? 0,
      );
      // Re-schedule local notification on this device if reminder was enabled.
      if (dailyReminderEnabled) {
        await _notificationService.scheduleDailyReminder(
          hour: reminderTime.hour,
          minute: reminderTime.minute,
        );
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleReminder(bool enabled) async {
    final previousValue = dailyReminderEnabled;
    dailyReminderEnabled = enabled;
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      if (enabled) {
        final granted = await _notificationService.requestPermissions();
        if (!granted) {
          // Permission denied – revert and inform user.
          dailyReminderEnabled = previousValue;
          errorMessage =
              'Notification permission was denied. Please enable it in App Settings.';
          isLoading = false;
          notifyListeners();
          return;
        }
        await _notificationService.scheduleDailyReminder(
          hour: reminderTime.hour,
          minute: reminderTime.minute,
        );
        successMessage =
            'Daily reminder set for ${_formatTime(reminderTime)} 🔔';
      } else {
        await _notificationService.cancelDailyReminder();
        successMessage = 'Daily reminder disabled.';
      }
      await saveToFirestore();
    } catch (error) {
      dailyReminderEnabled = previousValue;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> updateReminderTime(TimeOfDay time) async {
    final previousTime = reminderTime;
    reminderTime = time;
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      if (dailyReminderEnabled) {
        await _notificationService.scheduleDailyReminder(
          hour: time.hour,
          minute: time.minute,
        );
        successMessage =
            'Reminder rescheduled for ${_formatTime(time)} 🔔';
      }
      await saveToFirestore();
    } catch (error) {
      reminderTime = previousTime;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    isLoading = false;
    notifyListeners();
  }

  // sendTestNotification removed — test notifications are not required.

  Future<void> saveToFirestore() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User is not authenticated');
    }

    await _settingsRef(uid).set({
      'dailyReminderEnabled': dailyReminderEnabled,
      'dailyReminderHour': reminderTime.hour,
      'dailyReminderMinute': reminderTime.minute,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DocumentReference<Map<String, dynamic>> _settingsRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('userSettings')
        .doc('learning');
  }
}
