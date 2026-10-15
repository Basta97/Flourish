import 'credit_card_service.dart';
import '../utils/currency_formatter.dart';
import 'financial_ledger_service.dart';
import '../../domain/finance/models.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../data/finance/finance_store.dart';
import '../services/preferences_service.dart';

class ReminderService {
  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;
  Future<void> init() async {
    if (initialized) return;
    tzdata.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    initialized = true;
  }

  Future<void> enable() async {
    await init();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final allowed = android != null
        ? await android.requestNotificationsPermission()
        : await ios?.requestPermissions(alert: true, sound: true, badge: true);
    if (allowed != true) {
      throw StateError('Notification permission was not granted');
    }
    await PreferencesService.setBool('reminders_enabled', true);
  }

  Future<void> schedule(FinanceStore store) async {
    if (!PreferencesService.getBool('reminders_enabled')) return;
    await init();
    await plugin.cancelAllPendingNotifications();
    final contracts = await ContractRepository(store).getAll();
    final upcoming = <({String name, DateTime date, String body})>[];
    for (final c in contracts) {
      for (final p in await ContractRepository(store).payments(c.id)) {
        if (!p.paid) {
          upcoming.add((
            name: c.name,
            date: p.date,
            body: '${c.name}: review the scheduled payment.',
          ));
        }
      }
    }
    final cards = CreditCardService(FinancialLedgerService(store.db));
    for (final c in contracts) {
      if (c.kind == ContractKind.creditCard && c.cardAccountId != null) {
        final status = await cards.status(c.cardAccountId!);
        if (status.statementRemaining <= Amount.zero || status.due == null) {
          continue;
        }
        final digits = CurrencyFormatter.decimalsFor(c.currency);
        final body = status.terms == null
            ? '${c.name}: ${c.currency} ${status.statementRemaining.fixed(digits)} '
                  'of the last statement is unpaid.'
            : '${c.name}: pay at least ${c.currency} '
                  '${status.minimumDue.fixed(digits)}, or '
                  '${status.statementRemaining.fixed(digits)} in full to avoid '
                  'interest.';
        upcoming.add((
          name: '${c.name} payment due',
          date: status.due!,
          body: body,
        ));
        upcoming.add((
          name: '${c.name} payment due in 3 days',
          date: status.due!.subtract(const Duration(days: 3)),
          body: body,
        ));
      } else {
        final outstanding =
            c.principal -
            (await ContractRepository(store).payments(c.id))
                .where((p) => p.paid)
                .fold(Amount.zero, (sum, p) => sum + p.principal);
        if (outstanding > Amount.zero &&
            !upcoming.any((p) => p.name == c.name && p.date == c.maturity)) {
          upcoming.add((
            name: '${c.name} maturity',
            date: c.maturity,
            body: '${c.name} maturity: review the scheduled payment.',
          ));
        }
      }
    }
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    var id = 1;
    for (final entry in upcoming) {
      final date = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
        9,
      );
      if (date.isBefore(DateTime.now())) continue;
      await plugin.zonedSchedule(
        id: id++,
        title: 'Flourish payment reminder',
        body: entry.body,
        scheduledDate: tz.TZDateTime.from(date.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_due',
            'Financial due dates',
            channelDescription: 'Contract payments and maturities',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      if (id > 60) break;
    }
  }
}
