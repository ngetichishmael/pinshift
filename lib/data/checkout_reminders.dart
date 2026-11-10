import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pinshift/core/checkout_schedule.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class CheckoutReminders {
  CheckoutReminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Schedules a weekly Mon-Fri reminder at the start of each checkout window.
  /// Safe to call on every launch: ids are stable, so it just replaces them.
  static Future<void> schedule() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      final now = tz.TZDateTime.now(tz.local);
      for (final w in checkoutWindows) {
        for (final day in checkoutWeekdays) {
          final next = nextWeekdayAt(now, day, w.startHour, w.startMinute);
          await _plugin.zonedSchedule(
            id: w.id + day,
            scheduledDate: tz.TZDateTime.from(next, tz.local),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'checkout',
                'Checkout reminders',
                channelDescription: 'Weekday check-out window reminders',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: 'Time to check out',
            body: '${w.label} window is open (${w.range})',
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    } catch (e) {
      debugPrint('Checkout reminders not scheduled: $e');
    }
  }
}
