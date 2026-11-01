import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _registeredSubscription;
  StreamSubscription<String>? _unregisteredSubscription;
  static const String _promptedKey = 'pitfit_notification_permission_prompted';
  // FID tego urządzenia, potrzebny do usunięcia go przy wylogowaniu.
  String? _currentFid;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'pitfit_general',
    'Powiadomienia PitFit',
    description: 'Przypomnienia i podsumowania aktywności',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

        const settings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _notifications.initialize(settings: settings);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
    /// Prosi o zgodę na powiadomienia tylko raz, automatycznie po zalogowaniu.
  /// Jeśli użytkownik odmówi, może to zmienić w karcie „Powiadomienia”
  /// w profilu albo w ustawieniach systemu.
  Future<void> requestPermissionOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_promptedKey) == true) return;

      await requestPermission();
      await prefs.setBool(_promptedKey, true);
    } catch (e) {
      debugPrint('requestPermissionOnce błąd: $e');
    }
  }
  void startAuthListener() {
    _authSubscription?.cancel();
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('authStateChanges: ${user?.uid}');
      if (user != null) {
        registerFcmToken();
      }
    });
  }

  Future<void> registerFcmToken() async {
    debugPrint('registerFcmToken wywołane');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('registerFcmToken: brak zalogowanego użytkownika Firebase');
      return;
    }

    try {
      await _registeredSubscription?.cancel();
      await _unregisteredSubscription?.cancel();

      _registeredSubscription =
          FirebaseMessaging.instance.onRegistered.listen(
        (fid) {
          debugPrint('FID otrzymany: $fid');
          _currentFid = fid;
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            _saveFid(currentUser.uid, fid);
          } else {
            debugPrint('FID otrzymany, ale brak zalogowanego użytkownika');
          }
        },
        onError: (Object e) {
          debugPrint('onRegistered błąd strumienia: $e');
        },
      );

      _unregisteredSubscription =
          FirebaseMessaging.instance.onUnregistered.listen(
        (fid) {
          debugPrint('FID wyrejestrowany: $fid');
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            _removeFid(currentUser.uid, fid);
          }
        },
        onError: (Object e) {
          debugPrint('onUnregistered błąd strumienia: $e');
        },
      );

      await FirebaseMessaging.instance.register();
      debugPrint('register() zakończone');
    } catch (e, st) {
      debugPrint('registerFcmToken błąd: $e\n$st');
    }
  }

  Future<void> _saveFid(String uid, String fid) async {
    try {
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'web';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcmInstallations')
          .doc(fid)
          .set({
        'fid': fid,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': platform,
      });
      debugPrint('_saveFid: zapisano FID dla $uid');
    } catch (e) {
      debugPrint('_saveFid błąd: $e');
    }
  }

  Future<void> _removeFid(String uid, String fid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcmInstallations')
          .doc(fid)
          .delete();
      debugPrint('_removeFid: usunięto FID dla $uid');
    } catch (e) {
      debugPrint('_removeFid błąd: $e');
    }
  }

  /// Wywołuj PRZED wylogowaniem z Firebase, bo usuwa dokument urządzenia
  /// z Firestore, a po wylogowaniu reguły by na to nie pozwoliły.
  Future<void> removeFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final fid = _currentFid;

    try {
      if (user != null && fid != null) {
        await _removeFid(user.uid, fid);
      }
      await _registeredSubscription?.cancel();
      await _unregisteredSubscription?.cancel();
      _registeredSubscription = null;
      _unregisteredSubscription = null;
      await FirebaseMessaging.instance.unregister();
    } catch (e) {
      debugPrint('removeFcmToken błąd: $e');
    }

    _currentFid = null;
  }

  Future<void> showTestNotification() async {
    await _notifications.show(
      id: 1,
      title: 'PitFit',
      body: 'Powiadomienia działają poprawnie!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pitfit_general',
          'Powiadomienia PitFit',
          channelDescription: 'Przypomnienia i podsumowania aktywności',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}