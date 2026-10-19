import 'presentation/home_widgets/home_widget_runtime.dart';
import 'presentation/wealth/finance_runtime.dart';
import 'presentation/detection/detection_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/finance/financial_ledger_service.dart';
import 'core/finance/recurring_service.dart';
import 'core/services/preferences_service.dart';
import 'data/database/database.dart';
import 'presentation/providers/database_provider.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in assets/fonts; never download them at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final font in ['manrope', 'space_grotesk']) {
      final license = await rootBundle.loadString('assets/fonts/$font/OFL.txt');
      yield LicenseEntryWithLineBreaks(['google_fonts'], license);
    }
  });
  await PreferencesService.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final db = AppDatabase();

  try {
    await RecurringService(FinancialLedgerService(db)).processDue();
  } catch (e, st) {
    // Log but don't block app launch if recurring processing fails.
    // A background/resume check will retry later.
    debugPrint('Failed to process recurring transactions: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const FinanceRuntime(
        child: HomeWidgetRuntime(child: DetectionRuntime(child: FlourishApp())),
      ),
    ),
  );
}
