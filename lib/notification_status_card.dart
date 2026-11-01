import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'main.dart';
import 'services/notification_service.dart';

class NotificationStatusCard extends StatefulWidget {
  const NotificationStatusCard({super.key});

  @override
  State<NotificationStatusCard> createState() => _NotificationStatusCardState();
}

class _NotificationStatusCardState extends State<NotificationStatusCard>
    with WidgetsBindingObserver {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Po powrocie z ustawień systemu stan odświeża się sam.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      final enabled =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!mounted) return;
      setState(() => _enabled = enabled);
    } catch (e) {
      debugPrint('Nie udało się sprawdzić powiadomień: $e');
      if (!mounted) return;
      setState(() => _enabled = null);
    }
  }

  Future<void> _enable() async {
    setState(() => _busy = true);

    try {
      final granted = await NotificationService.instance.requestPermission();

      if (!mounted) return;
      await _refresh();

      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Powiadomienia są wyłączone. Włącz je w ustawieniach systemu: '
              'Aplikacje → PitFit → Powiadomienia.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pitFitCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: pitFitYellow),
              SizedBox(width: 10),
              Text(
                'Powiadomienia',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (enabled == null)
            const Text(
              'Sprawdzanie stanu powiadomień...',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            )
          else if (enabled) ...[
            const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Włączone. Dostaniesz powiadomienia o nowych wiadomościach.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: NotificationService.instance.showTestNotification,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Wyślij testowe powiadomienie'),
                style: TextButton.styleFrom(foregroundColor: pitFitYellow),
              ),
            ),
          ] else ...[
            const Row(
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  color: Colors.orangeAccent,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wyłączone. Nie dostaniesz powiadomień o wiadomościach.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _enable,
                style: FilledButton.styleFrom(
                  backgroundColor: pitFitYellow,
                  foregroundColor: pitFitNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.notifications_active_rounded),
                label: const Text(
                  'Włącz powiadomienia',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}