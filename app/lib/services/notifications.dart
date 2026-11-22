import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import '../domain/notification_plan.dart';

/// Two local notifications a day (decision 22 Nov): morning cards at 06:00 and mood shifts
/// (max one a day, not 21:00–08:00). Scheduled on the phone from the cached mood-shift list,
/// so they work offline. Re-planned every time the app opens or settings change.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _openHome = ValueNotifier<int>(0); // bumps when a notification is tapped
  ValueListenable<int> get opened => _openHome;
  bool _ready = false;
  late tz.Location _local;

  static const _channelId = 'daily_cards';
  static const _morningBase = 1000; // ids 1000..1006
  static const _moodBase = 2000; // ids 2000..2009

  Future<String> init() async {
    tzdata.initializeTimeZones();
    String name;
    try {
      name = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      name = 'America/Sao_Paulo';
    }
    try {
      _local = tz.getLocation(name);
    } catch (_) {
      _local = tz.getLocation('America/Sao_Paulo');
      name = 'America/Sao_Paulo';
    }
    tz.setLocalLocation(_local);
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (_) => _openHome.value++,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _openHome.value++;
    _ready = true;
    return name;
  }

  String get timeZoneName => _local.name;

  /// Android 13+ POST_NOTIFICATIONS (4g). Returns whether she allowed it.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> enabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  Future<void> plan({
    required bool morning,
    required bool mood,
    required List<MoodShift> shifts,
    required ({String morningTitle, String morningBody, String moodTitle, String moodBody, String channel}) text,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(_channelId, text.channel, importance: Importance.defaultImportance),
    );
    final now = tz.TZDateTime.now(_local);

    if (morning) {
      for (var i = 0; i < 7; i++) {
        final at = tz.TZDateTime(_local, now.year, now.month, now.day + i, morningHour);
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _morningBase + i,
          title: text.morningTitle,
          body: text.morningBody,
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
    if (mood) {
      final picks = notifiableShifts(shifts, (utc) => tz.TZDateTime.from(utc, _local))
          .where((s) => s.at.isAfter(now.toUtc()))
          .take(10)
          .toList();
      for (var i = 0; i < picks.length; i++) {
        await _plugin.zonedSchedule(
          id: _moodBase + i,
          title: text.moodTitle,
          body: text.moodBody,
          scheduledDate: tz.TZDateTime.from(picks[i].at, _local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
