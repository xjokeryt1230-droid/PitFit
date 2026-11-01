
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class StepTrackingService {
  final Health _health = Health();

  Future<void> _configure() async {
    await _health.configure();
  }

  Future<bool> isAvailable() async {
    try {
      await _configure();

      final status = await _health.getHealthConnectSdkStatus();

      debugPrint('Health Connect SDK status: $status');
      debugPrint('Health Connect SDK native value: ${status?.nativeValue}');

      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e, stackTrace) {
      debugPrint('Błąd sprawdzania Health Connect: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      await _configure();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final activityStatus =
            await Permission.activityRecognition.request();

        debugPrint('Activity Recognition: $activityStatus');

        if (!activityStatus.isGranted) {
          return false;
        }
      }

      final granted = await _health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );

      debugPrint('Health Connect — dostęp do kroków: $granted');

      return granted;
    } catch (e, stackTrace) {
      debugPrint('Błąd Health Connect: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<int> getTodaySteps() async {
    try {
      await _configure();

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);

      final steps = await _health.getTotalStepsInInterval(start, now);
      return steps ?? 0;
    } catch (e) {
      debugPrint('Błąd odczytu kroków: $e');
      return 0;
    }
  }

  Future<List<int>> getLast7DaysSteps() async {
  await _configure();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final results = <int>[];

  for (int i = 6; i >= 0; i--) {
    final dayStart = today.subtract(Duration(days: i));
    final dayEnd = dayStart.add(const Duration(days: 1));
    final end = dayEnd.isAfter(now) ? now : dayEnd;

    try {
      final steps = await _health.getTotalStepsInInterval(
        dayStart,
        end,
      );
      results.add(steps ?? 0);
    } catch (e) {
      debugPrint('Błąd odczytu kroków: $e');
      results.add(0);
    }
  }

  return results;
}

}
