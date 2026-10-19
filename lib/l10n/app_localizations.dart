import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Flourish'**
  String get appTitle;

  /// No description provided for @greetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get greetingNight;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @showAmounts.
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get showAmounts;

  /// No description provided for @hideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get hideAmounts;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @paymentsToReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment to review} other{{count} payments to review}}'**
  String paymentsToReview(int count);

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @spending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get spending;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @needHistoricalRates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction needs historical exchange rates.} other{{count} transactions need historical exchange rates.}}'**
  String needHistoricalRates(int count);

  /// No description provided for @holdings.
  ///
  /// In en, this message translates to:
  /// **'Holdings'**
  String get holdings;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivityYet;

  /// No description provided for @noActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first transaction and it will show up here.'**
  String get noActivitySubtitle;

  /// No description provided for @getStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Let’s get you set up'**
  String get getStartedTitle;

  /// No description provided for @getStartedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add an account and your first transaction to get started.'**
  String get getStartedSubtitle;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// No description provided for @addAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Add an account'**
  String get addAnAccount;

  /// No description provided for @motivationTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily boost'**
  String get motivationTitle;

  /// No description provided for @motivationWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Nice work'**
  String get motivationWinTitle;

  /// No description provided for @motivationNextHint.
  ///
  /// In en, this message translates to:
  /// **'Shows another encouraging line'**
  String get motivationNextHint;

  /// No description provided for @motivationSaved.
  ///
  /// In en, this message translates to:
  /// **'You kept {amount} this month. Keep it growing!'**
  String motivationSaved(String amount);

  /// No description provided for @motivationGoalMilestone.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of “{goal}” reached. You’re getting there!'**
  String motivationGoalMilestone(int percent, String goal);

  /// No description provided for @motivationGoalDone.
  ///
  /// In en, this message translates to:
  /// **'“{goal}” is fully funded. Well done!'**
  String motivationGoalDone(String goal);

  /// No description provided for @motivationQuote1.
  ///
  /// In en, this message translates to:
  /// **'Small steps today, more freedom tomorrow.'**
  String get motivationQuote1;

  /// No description provided for @motivationQuote2.
  ///
  /// In en, this message translates to:
  /// **'Every amount you track is money you control.'**
  String get motivationQuote2;

  /// No description provided for @motivationQuote3.
  ///
  /// In en, this message translates to:
  /// **'Saving a little beats saving nothing.'**
  String get motivationQuote3;

  /// No description provided for @motivationQuote4.
  ///
  /// In en, this message translates to:
  /// **'Your future self will thank you.'**
  String get motivationQuote4;

  /// No description provided for @motivationQuote5.
  ///
  /// In en, this message translates to:
  /// **'Consistency beats intensity. Log today’s spending.'**
  String get motivationQuote5;

  /// No description provided for @motivationQuote6.
  ///
  /// In en, this message translates to:
  /// **'A budget tells your money where to go.'**
  String get motivationQuote6;

  /// No description provided for @motivationQuote7.
  ///
  /// In en, this message translates to:
  /// **'Progress, not perfection.'**
  String get motivationQuote7;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get navLedger;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navWealth.
  ///
  /// In en, this message translates to:
  /// **'Wealth'**
  String get navWealth;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'The page \"{page}\" does not exist.'**
  String pageNotFound(String page);

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get accountNotFound;

  /// No description provided for @accountNotFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'That account link is invalid or no longer available.'**
  String get accountNotFoundSubtitle;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @scanOrImport.
  ///
  /// In en, this message translates to:
  /// **'Scan or import'**
  String get scanOrImport;

  /// No description provided for @whatToAdd.
  ///
  /// In en, this message translates to:
  /// **'WHAT DO YOU WANT TO ADD?'**
  String get whatToAdd;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeName.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, light{Light} dark{Dark} other{System}}'**
  String themeName(String mode);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDevice.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageDevice;

  /// No description provided for @hideAmountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show balances as dots until you tap the eye'**
  String get hideAmountsSubtitle;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get defaultCurrency;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @budgetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spending limits by category'**
  String get budgetsSubtitle;

  /// No description provided for @savingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get savingsGoals;

  /// No description provided for @savingsGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Targets and progress'**
  String get savingsGoalsSubtitle;

  /// No description provided for @recurringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bills, salaries and subscriptions'**
  String get recurringSubtitle;

  /// No description provided for @cardsWallets.
  ///
  /// In en, this message translates to:
  /// **'Cards & wallets'**
  String get cardsWallets;

  /// No description provided for @cardsWalletsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Debit and credit cards, wallets, InstaPay'**
  String get cardsWalletsSubtitle;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @categoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or delete transaction categories'**
  String get categoriesSubtitle;

  /// No description provided for @paymentDetection.
  ///
  /// In en, this message translates to:
  /// **'Payment detection'**
  String get paymentDetection;

  /// No description provided for @paymentDetectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find payments in bank and wallet alerts'**
  String get paymentDetectionSubtitle;

  /// No description provided for @smartImport.
  ///
  /// In en, this message translates to:
  /// **'Smart Import'**
  String get smartImport;

  /// No description provided for @smartImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste bank alerts to create transactions'**
  String get smartImportSubtitle;

  /// No description provided for @monthlyAutoIncome.
  ///
  /// In en, this message translates to:
  /// **'Monthly Auto Income'**
  String get monthlyAutoIncome;

  /// No description provided for @autoMonthlyIncome.
  ///
  /// In en, this message translates to:
  /// **'Auto Monthly Income'**
  String get autoMonthlyIncome;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @monthlyIncomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Monthly Income Amount'**
  String get monthlyIncomeAmount;

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of Month'**
  String get dayOfMonth;

  /// No description provided for @incomeAccount.
  ///
  /// In en, this message translates to:
  /// **'Income Account'**
  String get incomeAccount;

  /// No description provided for @selectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get selectAccount;

  /// No description provided for @incomeCategory.
  ///
  /// In en, this message translates to:
  /// **'Income Category'**
  String get incomeCategory;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your data as JSON'**
  String get exportDataSubtitle;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @importDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a JSON backup'**
  String get importDataSubtitle;

  /// No description provided for @resetAllData.
  ///
  /// In en, this message translates to:
  /// **'Reset All Data'**
  String get resetAllData;

  /// No description provided for @resetAllDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all accounts, transactions, and budgets'**
  String get resetAllDataSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @builtWith.
  ///
  /// In en, this message translates to:
  /// **'Built with'**
  String get builtWith;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @invalidBackup.
  ///
  /// In en, this message translates to:
  /// **'Invalid or empty backup file.'**
  String get invalidBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get importBackup;

  /// No description provided for @importBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'This will erase all current data and replace it with the backup. This cannot be undone.'**
  String get importBackupWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Complete backup restored.'**
  String get backupRestored;

  /// No description provided for @importedRecords.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} records successfully.'**
  String importedRecords(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @resetAllDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This will delete all your accounts, transactions, budgets, and settings. This cannot be undone.'**
  String get resetAllDataWarning;

  /// No description provided for @allDataReset.
  ///
  /// In en, this message translates to:
  /// **'All data has been reset'**
  String get allDataReset;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @toolsMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get toolsMoney;

  /// No description provided for @toolsImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import & export'**
  String get toolsImportExport;

  /// No description provided for @toolsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security & backup'**
  String get toolsSecurity;

  /// No description provided for @exchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get exchangeRates;

  /// No description provided for @exchangeRatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sources, dates, and manual overrides'**
  String get exchangeRatesSubtitle;

  /// No description provided for @manageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get manageAccounts;

  /// No description provided for @manageAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit, group, archive, and reconcile balances'**
  String get manageAccountsSubtitle;

  /// No description provided for @savedTemplates.
  ///
  /// In en, this message translates to:
  /// **'Saved transaction templates'**
  String get savedTemplates;

  /// No description provided for @savedTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse frequent entries'**
  String get savedTemplatesSubtitle;

  /// No description provided for @subcategories.
  ///
  /// In en, this message translates to:
  /// **'Subcategories'**
  String get subcategories;

  /// No description provided for @subcategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Split categories into finer groups'**
  String get subcategoriesSubtitle;

  /// No description provided for @receiptAttachments.
  ///
  /// In en, this message translates to:
  /// **'Receipt attachments'**
  String get receiptAttachments;

  /// No description provided for @receiptAttachmentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photos and files linked to entries'**
  String get receiptAttachmentsSubtitle;

  /// No description provided for @reportingMonthStarts.
  ///
  /// In en, this message translates to:
  /// **'Reporting month starts on'**
  String get reportingMonthStarts;

  /// No description provided for @dayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String dayNumber(int day);

  /// No description provided for @reportingMonth.
  ///
  /// In en, this message translates to:
  /// **'Reporting month'**
  String get reportingMonth;

  /// No description provided for @startDayRange.
  ///
  /// In en, this message translates to:
  /// **'Start day (1–28)'**
  String get startDayRange;

  /// No description provided for @chooseDayRange.
  ///
  /// In en, this message translates to:
  /// **'Choose a day from 1 to 28'**
  String get chooseDayRange;

  /// No description provided for @importFromApps.
  ///
  /// In en, this message translates to:
  /// **'Import from other apps'**
  String get importFromApps;

  /// No description provided for @importFromAppsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money Manager, Wallet, Monefy, Spendee, YNAB, bank CSV, OFX, QIF, Excel or PDF statements · review before anything is added'**
  String get importFromAppsSubtitle;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export transactions as CSV'**
  String get exportCsv;

  /// No description provided for @exportCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opens in any spreadsheet app'**
  String get exportCsvSubtitle;

  /// No description provided for @paymentReminders.
  ///
  /// In en, this message translates to:
  /// **'Payment reminders'**
  String get paymentReminders;

  /// No description provided for @paymentRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local notifications for expected payments and maturities'**
  String get paymentRemindersSubtitle;

  /// No description provided for @paymentRemindersEnabled.
  ///
  /// In en, this message translates to:
  /// **'Payment reminders enabled'**
  String get paymentRemindersEnabled;

  /// No description provided for @deviceLock.
  ///
  /// In en, this message translates to:
  /// **'Device authentication lock'**
  String get deviceLock;

  /// No description provided for @deviceLockOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled · tap to disable'**
  String get deviceLockOn;

  /// No description provided for @deviceLockOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled · tap to enable'**
  String get deviceLockOff;

  /// No description provided for @setUpPasscodeFirst.
  ///
  /// In en, this message translates to:
  /// **'Set up your device passcode first'**
  String get setUpPasscodeFirst;

  /// No description provided for @changeAppLockReason.
  ///
  /// In en, this message translates to:
  /// **'Change Flourish app lock'**
  String get changeAppLockReason;

  /// No description provided for @stockApiKey.
  ///
  /// In en, this message translates to:
  /// **'Stock quote API key'**
  String get stockApiKey;

  /// No description provided for @stockApiKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional Alpha Vantage key · stored securely on this device'**
  String get stockApiKeySubtitle;

  /// No description provided for @alphaVantageKey.
  ///
  /// In en, this message translates to:
  /// **'Alpha Vantage API key'**
  String get alphaVantageKey;

  /// No description provided for @personalApiKey.
  ///
  /// In en, this message translates to:
  /// **'Personal API key'**
  String get personalApiKey;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get exportBackup;

  /// No description provided for @exportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Includes holdings, contracts, activity, settings, and receipts'**
  String get exportBackupSubtitle;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore encrypted backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replaces everything with a backup file'**
  String get restoreBackupSubtitle;

  /// No description provided for @backupHistory.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup history'**
  String get backupHistory;

  /// No description provided for @backupHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Seven local daily backups · remain on this device'**
  String get backupHistorySubtitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enterField.
  ///
  /// In en, this message translates to:
  /// **'Enter {field}'**
  String enterField(String field);

  /// No description provided for @owedCaps.
  ///
  /// In en, this message translates to:
  /// **'OWED'**
  String get owedCaps;

  /// No description provided for @creditBalanceCaps.
  ///
  /// In en, this message translates to:
  /// **'CREDIT BALANCE'**
  String get creditBalanceCaps;

  /// No description provided for @nothingOwedCaps.
  ///
  /// In en, this message translates to:
  /// **'NOTHING OWED'**
  String get nothingOwedCaps;

  /// No description provided for @noPaymentAccounts.
  ///
  /// In en, this message translates to:
  /// **'No bank, wallet or card accounts'**
  String get noPaymentAccounts;

  /// No description provided for @addOneFromAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add one from Accounts first'**
  String get addOneFromAccounts;

  /// No description provided for @searchTransactionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search transactions...'**
  String get searchTransactionsHint;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @searchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get searchTransactions;

  /// No description provided for @searchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type to search by note or type'**
  String get searchSubtitle;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock your Flourish finances'**
  String get unlockReason;

  /// No description provided for @authCancelled.
  ///
  /// In en, this message translates to:
  /// **'Authentication cancelled'**
  String get authCancelled;

  /// No description provided for @unlockToContinue.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your device authentication to continue.'**
  String get unlockToContinue;

  /// No description provided for @financesLocked.
  ///
  /// In en, this message translates to:
  /// **'Your finances are locked.'**
  String get financesLocked;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @screenshotAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Read screenshots with AI?'**
  String get screenshotAiTitle;

  /// No description provided for @screenshotAiBody.
  ///
  /// In en, this message translates to:
  /// **'Android\'s on-device text reader cannot read Arabic. With this on, a screenshot you choose to read with AI is sent as an image to {provider}. An image cannot be masked: names, card or account numbers and balances visible in it are sent too.'**
  String screenshotAiBody(String provider);

  /// No description provided for @freeTiersKeep.
  ///
  /// In en, this message translates to:
  /// **'Free tiers may keep what you send.'**
  String get freeTiersKeep;

  /// No description provided for @screenshotAiFooter.
  ///
  /// In en, this message translates to:
  /// **'On-device reading stays the default; nothing is sent until you tap \"Read with AI\". You can turn this off in AI settings.'**
  String get screenshotAiFooter;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @pick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get pick;

  /// No description provided for @futureDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Date is in the future'**
  String get futureDateTitle;

  /// No description provided for @futureDateBody.
  ///
  /// In en, this message translates to:
  /// **'This entry is dated {date} but changes the account balance now. For a payment that has not happened yet, a recurring payment or reminder may fit better.'**
  String futureDateBody(String date);

  /// No description provided for @changeDate.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get changeDate;

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnyway;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction?'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the transaction and rebalances the linked account automatically.'**
  String get deleteTransactionBody;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transactionDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @manageAccount.
  ///
  /// In en, this message translates to:
  /// **'Manage account'**
  String get manageAccount;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @errorLoadingTransactions.
  ///
  /// In en, this message translates to:
  /// **'Error loading transactions'**
  String get errorLoadingTransactions;

  /// No description provided for @errorLoadingAccount.
  ///
  /// In en, this message translates to:
  /// **'Error loading account'**
  String get errorLoadingAccount;

  /// No description provided for @transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transaction;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Accounts with transactions must be archived instead, so their history stays in your reports.'**
  String deleteAccountBody(String name);

  /// No description provided for @inThisMonth.
  ///
  /// In en, this message translates to:
  /// **'In this month'**
  String get inThisMonth;

  /// No description provided for @outThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Out this month'**
  String get outThisMonth;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get noTransactions;

  /// No description provided for @addTransactionToStart.
  ///
  /// In en, this message translates to:
  /// **'Add a transaction to get started.'**
  String get addTransactionToStart;

  /// No description provided for @cardsWalletsHelp.
  ///
  /// In en, this message translates to:
  /// **'Add the cards and wallets that pay from this account so spending shows what paid and detected payments find the right account.'**
  String get cardsWalletsHelp;

  /// No description provided for @defaultLower.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get defaultLower;

  /// No description provided for @fxFee.
  ///
  /// In en, this message translates to:
  /// **'FX fee {percent}%'**
  String fxFee(String percent);

  /// No description provided for @cashNoCards.
  ///
  /// In en, this message translates to:
  /// **'Cash accounts have no cards or wallets'**
  String get cashNoCards;

  /// No description provided for @addCardOrWallet.
  ///
  /// In en, this message translates to:
  /// **'Add card or wallet'**
  String get addCardOrWallet;

  /// No description provided for @editNamed.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editNamed(String name);

  /// No description provided for @instrumentName.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. CIB Visa)'**
  String get instrumentName;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @cardNetwork.
  ///
  /// In en, this message translates to:
  /// **'Card network'**
  String get cardNetwork;

  /// No description provided for @noneNotCard.
  ///
  /// In en, this message translates to:
  /// **'None / not a card'**
  String get noneNotCard;

  /// No description provided for @last4Digits.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits (matches bank messages)'**
  String get last4Digits;

  /// No description provided for @bankOrWallet.
  ///
  /// In en, this message translates to:
  /// **'Bank or wallet'**
  String get bankOrWallet;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @walletHandle.
  ///
  /// In en, this message translates to:
  /// **'Wallet number or InstaPay address'**
  String get walletHandle;

  /// No description provided for @foreignFeeOptional.
  ///
  /// In en, this message translates to:
  /// **'Foreign transaction fee, % (optional)'**
  String get foreignFeeOptional;

  /// No description provided for @defaultForAccount.
  ///
  /// In en, this message translates to:
  /// **'Default for this account'**
  String get defaultForAccount;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @inUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get inUse;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get noCategories;

  /// No description provided for @errorLoadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Error loading categories'**
  String get errorLoadingCategories;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @systemCategoryLocked.
  ///
  /// In en, this message translates to:
  /// **'Used for automatic entries; cannot be deleted'**
  String get systemCategoryLocked;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategory;

  /// No description provided for @deleteCategoryWithTx.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has {count} transactions. They will move to \"{target}\", and budgets for this category will be removed.'**
  String deleteCategoryWithTx(String name, int count, String target);

  /// No description provided for @otherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get otherIncome;

  /// No description provided for @deleteCategoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Budgets for it will be removed.'**
  String deleteCategoryEmpty(String name);

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryName;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get enterName;

  /// No description provided for @noAccountsYet.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccountsYet;

  /// No description provided for @addFirstAccount.
  ///
  /// In en, this message translates to:
  /// **'Add your first account to start tracking.'**
  String get addFirstAccount;

  /// No description provided for @accountCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ACCOUNT} other{{count} ACCOUNTS}}'**
  String accountCount(int count);

  /// No description provided for @errorLoadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Error loading accounts'**
  String get errorLoadingAccounts;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// No description provided for @accountNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Main Bank'**
  String get accountNameHint;

  /// No description provided for @amountOweNow.
  ///
  /// In en, this message translates to:
  /// **'Amount you owe now'**
  String get amountOweNow;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get currentBalance;

  /// No description provided for @debtPositiveHint.
  ///
  /// In en, this message translates to:
  /// **'Enter debt as a positive number; 0 for a paid-off card'**
  String get debtPositiveHint;

  /// No description provided for @leaveEmptyZero.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for 0'**
  String get leaveEmptyZero;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountType;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @cardTerms.
  ///
  /// In en, this message translates to:
  /// **'Card terms'**
  String get cardTerms;

  /// No description provided for @creditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get creditLimit;

  /// No description provided for @interestPerYear.
  ///
  /// In en, this message translates to:
  /// **'Interest % / year'**
  String get interestPerYear;

  /// No description provided for @statementDay.
  ///
  /// In en, this message translates to:
  /// **'Statement day'**
  String get statementDay;

  /// No description provided for @dueDay.
  ///
  /// In en, this message translates to:
  /// **'Due day'**
  String get dueDay;

  /// No description provided for @cardFeesLater.
  ///
  /// In en, this message translates to:
  /// **'Fees (foreign transactions, cash advance, late payment) can be added from the card page.'**
  String get cardFeesLater;

  /// No description provided for @enterAccountName.
  ///
  /// In en, this message translates to:
  /// **'Please enter an account name'**
  String get enterAccountName;

  /// No description provided for @maxDecimals.
  ///
  /// In en, this message translates to:
  /// **'Use at most {count} decimals'**
  String maxDecimals(int count);

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfers;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @calendarView.
  ///
  /// In en, this message translates to:
  /// **'Calendar view'**
  String get calendarView;

  /// No description provided for @allAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get allAccounts;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @showingDay.
  ///
  /// In en, this message translates to:
  /// **'Showing {day} · show whole month'**
  String showingDay(String day);

  /// No description provided for @couldNotLoadTransactions.
  ///
  /// In en, this message translates to:
  /// **'Could not load transactions'**
  String get couldNotLoadTransactions;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @noTransactionsPeriod.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period.'**
  String get noTransactionsPeriod;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @chooseDateRange.
  ///
  /// In en, this message translates to:
  /// **'Choose date range'**
  String get chooseDateRange;

  /// No description provided for @clearRange.
  ///
  /// In en, this message translates to:
  /// **'Clear range'**
  String get clearRange;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @noGoalsYet.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get noGoalsYet;

  /// No description provided for @noGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a savings goal to start tracking progress.'**
  String get noGoalsSubtitle;

  /// No description provided for @errorLoadingGoals.
  ///
  /// In en, this message translates to:
  /// **'Error loading goals'**
  String get errorLoadingGoals;

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get goalReached;

  /// No description provided for @percentSaved.
  ///
  /// In en, this message translates to:
  /// **'{percent}% saved'**
  String percentSaved(String percent);

  /// No description provided for @ofTarget.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String ofTarget(String amount);

  /// No description provided for @pastDeadline.
  ///
  /// In en, this message translates to:
  /// **'Past deadline'**
  String get pastDeadline;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String daysLeft(int count);

  /// No description provided for @deleteGoal.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get deleteGoal;

  /// No description provided for @deleteGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete goal?'**
  String get deleteGoalTitle;

  /// No description provided for @deleteGoalBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" and its progress will be removed.'**
  String deleteGoalBody(String name);

  /// No description provided for @addToGoal.
  ///
  /// In en, this message translates to:
  /// **'Add to \"{name}\"'**
  String addToGoal(String name);

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @contribute.
  ///
  /// In en, this message translates to:
  /// **'Contribute'**
  String get contribute;

  /// No description provided for @newSavingsGoal.
  ///
  /// In en, this message translates to:
  /// **'New Savings Goal'**
  String get newSavingsGoal;

  /// No description provided for @goalName.
  ///
  /// In en, this message translates to:
  /// **'Goal Name'**
  String get goalName;

  /// No description provided for @goalNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. New Laptop'**
  String get goalNameHint;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target Amount'**
  String get targetAmount;

  /// No description provided for @deadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get deadline;

  /// No description provided for @linkedAccount.
  ///
  /// In en, this message translates to:
  /// **'Linked Account'**
  String get linkedAccount;

  /// No description provided for @createGoal.
  ///
  /// In en, this message translates to:
  /// **'Create Goal'**
  String get createGoal;

  /// No description provided for @addCashOrBankFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a cash or bank account first'**
  String get addCashOrBankFirst;

  /// No description provided for @apiKeyRemoved.
  ///
  /// In en, this message translates to:
  /// **'API key removed'**
  String get apiKeyRemoved;

  /// No description provided for @apiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API key saved'**
  String get apiKeySaved;

  /// No description provided for @saveApiKeyFirst.
  ///
  /// In en, this message translates to:
  /// **'Save an API key first'**
  String get saveApiKeyFirst;

  /// No description provided for @noModelsForKey.
  ///
  /// In en, this message translates to:
  /// **'No models available for this key'**
  String get noModelsForKey;

  /// No description provided for @addAiConfigFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a base URL, model and API key first'**
  String get addAiConfigFirst;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {model}'**
  String connectedTo(String model);

  /// No description provided for @connectedNoJson.
  ///
  /// In en, this message translates to:
  /// **'Connected, but the model did not follow the JSON instruction. Try another model.'**
  String get connectedNoJson;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @useAiWhenUnsure.
  ///
  /// In en, this message translates to:
  /// **'Use AI when unsure'**
  String get useAiWhenUnsure;

  /// No description provided for @useAiWhenUnsureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Flourish reads alerts on your phone first. Only messages it cannot read confidently are sent to the AI.'**
  String get useAiWhenUnsureSubtitle;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @freeTier.
  ///
  /// In en, this message translates to:
  /// **'{provider} · free tier'**
  String freeTier(String provider);

  /// No description provided for @baseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @chooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get chooseModel;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @apiKeySavedHint.
  ///
  /// In en, this message translates to:
  /// **'•••••••• (saved)'**
  String get apiKeySavedHint;

  /// No description provided for @pasteYourKey.
  ///
  /// In en, this message translates to:
  /// **'Paste your key'**
  String get pasteYourKey;

  /// No description provided for @saveKey.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get saveKey;

  /// No description provided for @keyStorageNote.
  ///
  /// In en, this message translates to:
  /// **'Stored in the device keychain. Leave empty and save to remove it.'**
  String get keyStorageNote;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @askBelowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI below {percent}% confidence'**
  String askBelowConfidence(int percent);

  /// No description provided for @percentConfidence.
  ///
  /// In en, this message translates to:
  /// **'{percent}% confidence'**
  String percentConfidence(int percent);

  /// No description provided for @higherSendsMore.
  ///
  /// In en, this message translates to:
  /// **'Higher sends more messages to the AI (better accuracy, more requests).'**
  String get higherSendsMore;

  /// No description provided for @aiSuggestCategories.
  ///
  /// In en, this message translates to:
  /// **'Let AI suggest new categories'**
  String get aiSuggestCategories;

  /// No description provided for @aiSuggestCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New categories are shown with ✨ and only created when you save.'**
  String get aiSuggestCategoriesSubtitle;

  /// No description provided for @hidePersonalData.
  ///
  /// In en, this message translates to:
  /// **'Hide personal data'**
  String get hidePersonalData;

  /// No description provided for @hidePersonalDataFree.
  ///
  /// In en, this message translates to:
  /// **'Always on for free providers, which may keep prompts.'**
  String get hidePersonalDataFree;

  /// No description provided for @hidePersonalDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Masks account and card numbers, phones and emails before sending.'**
  String get hidePersonalDataSubtitle;

  /// No description provided for @readArabicScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Read Arabic screenshots with AI'**
  String get readArabicScreenshots;

  /// No description provided for @providerNoImages.
  ///
  /// In en, this message translates to:
  /// **'{provider} cannot read images; choose a model that can, such as Gemini.'**
  String providerNoImages(String provider);

  /// No description provided for @sendsImageUnmasked.
  ///
  /// In en, this message translates to:
  /// **'Sends the image itself, unmasked, when you tap \"Read with AI\" in Smart Import.'**
  String get sendsImageUnmasked;

  /// No description provided for @aiUsageThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month: {requests} requests · {tokens} tokens'**
  String aiUsageThisMonth(String requests, String tokens);

  /// No description provided for @aiConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get aiConnection;

  /// No description provided for @aiBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get aiBehaviour;

  /// No description provided for @aiUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get aiUsage;

  /// No description provided for @importedSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 transaction} other{Imported {count} transactions}}'**
  String importedSummary(int count);

  /// No description provided for @skippedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String skippedCount(int count);

  /// No description provided for @reconcileOpening.
  ///
  /// In en, this message translates to:
  /// **'Reconcile opening balances if needed.'**
  String get reconcileOpening;

  /// No description provided for @reviewImport.
  ///
  /// In en, this message translates to:
  /// **'Review import'**
  String get reviewImport;

  /// No description provided for @importCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 transaction} other{Import {count} transactions}}'**
  String importCount(int count);

  /// No description provided for @newCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String newCount(int count);

  /// No description provided for @alreadyImportedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} already imported'**
  String alreadyImportedCount(int count);

  /// No description provided for @possibleDuplicatesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} possible duplicates'**
  String possibleDuplicatesCount(int count);

  /// No description provided for @unreadableCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unreadable'**
  String unreadableCount(int count);

  /// No description provided for @unverifiedLayout.
  ///
  /// In en, this message translates to:
  /// **'This layout was built from documentation, not a real export. Check a few rows below before importing.'**
  String get unverifiedLayout;

  /// No description provided for @andMore.
  ///
  /// In en, this message translates to:
  /// **'…and {count} more'**
  String andMore(int count);

  /// No description provided for @accountInFile.
  ///
  /// In en, this message translates to:
  /// **'“{name}” in the file · {rows}'**
  String accountInFile(String name, String rows);

  /// No description provided for @rowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String rowCount(int count);

  /// No description provided for @createNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create new account ({currency})'**
  String createNewAccount(String currency);

  /// No description provided for @categoriesNotInApp.
  ///
  /// In en, this message translates to:
  /// **'Categories not in Flourish'**
  String get categoriesNotInApp;

  /// No description provided for @chooseCategoryDest.
  ///
  /// In en, this message translates to:
  /// **'Choose where each one goes. New categories keep the parent from the file.'**
  String get chooseCategoryDest;

  /// No description provided for @createNamed.
  ///
  /// In en, this message translates to:
  /// **'Create “{name}”'**
  String createNamed(String name);

  /// No description provided for @changePerAccount.
  ///
  /// In en, this message translates to:
  /// **'Change per account'**
  String get changePerAccount;

  /// No description provided for @nothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get nothingSelected;

  /// No description provided for @alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already imported'**
  String get alreadyImported;

  /// No description provided for @possibleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get possibleDuplicate;

  /// No description provided for @cannotImport.
  ///
  /// In en, this message translates to:
  /// **'Cannot import'**
  String get cannotImport;

  /// No description provided for @moreRowsFollow.
  ///
  /// In en, this message translates to:
  /// **'{count} more rows follow the same choices'**
  String moreRowsFollow(int count);

  /// No description provided for @noTextTryAi.
  ///
  /// In en, this message translates to:
  /// **'No readable text found. For Arabic, try \"Read with AI\".'**
  String get noTextTryAi;

  /// No description provided for @noTextTypeInstead.
  ///
  /// In en, this message translates to:
  /// **'No readable text found. Type or paste the alert instead.'**
  String get noTextTypeInstead;

  /// No description provided for @textRecognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'Text recognition failed: {error}'**
  String textRecognitionFailed(String error);

  /// No description provided for @providerNoImagesSettings.
  ///
  /// In en, this message translates to:
  /// **'{provider} cannot read images. Choose a model that can, such as Gemini, in AI settings.'**
  String providerNoImagesSettings(String provider);

  /// No description provided for @aiNoText.
  ///
  /// In en, this message translates to:
  /// **'The AI found no readable text in this image.'**
  String get aiNoText;

  /// No description provided for @modelCannotReadImage.
  ///
  /// In en, this message translates to:
  /// **'This model could not read the image ({error}). Choose a model that reads images in AI settings.'**
  String modelCannotReadImage(String error);

  /// No description provided for @aiReadingFailed.
  ///
  /// In en, this message translates to:
  /// **'AI reading failed: {error}'**
  String aiReadingFailed(String error);

  /// No description provided for @aiUnavailableOnDevice.
  ///
  /// In en, this message translates to:
  /// **'AI unavailable, showing on-device results'**
  String get aiUnavailableOnDevice;

  /// No description provided for @noNewPayments.
  ///
  /// In en, this message translates to:
  /// **'No new payments found'**
  String get noNewPayments;

  /// No description provided for @paymentsReady.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment ready to review} other{{count} payments ready to review}}'**
  String paymentsReady(int count);

  /// No description provided for @skippedNotices.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped (codes, offers, notices or already added)'**
  String skippedNotices(int count);

  /// No description provided for @couldNotAnalyse.
  ///
  /// In en, this message translates to:
  /// **'Could not analyse: {error}'**
  String couldNotAnalyse(String error);

  /// No description provided for @reviewSharedScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Review shared payment screenshot'**
  String get reviewSharedScreenshot;

  /// No description provided for @pasteAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste bank, wallet or Apple Pay alerts'**
  String get pasteAlertsTitle;

  /// No description provided for @pasteAlertsBody.
  ///
  /// In en, this message translates to:
  /// **'Paste one alert or many at once. Each one is read on your phone and added to Payments to review.'**
  String get pasteAlertsBody;

  /// No description provided for @keepAsReceipt.
  ///
  /// In en, this message translates to:
  /// **'Keep this image as a receipt'**
  String get keepAsReceipt;

  /// No description provided for @readWithAiArabic.
  ///
  /// In en, this message translates to:
  /// **'Read with AI (Arabic)'**
  String get readWithAiArabic;

  /// No description provided for @alertText.
  ///
  /// In en, this message translates to:
  /// **'Alert text'**
  String get alertText;

  /// No description provided for @alertTextFrom.
  ///
  /// In en, this message translates to:
  /// **'Alert text (from {source})'**
  String alertTextFrom(String source);

  /// No description provided for @alertExample.
  ///
  /// In en, this message translates to:
  /// **'Example: Apple Pay: Card 1234 spent 24.90 USD at Starbucks'**
  String get alertExample;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @analyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get analyze;

  /// No description provided for @aiSecondReading.
  ///
  /// In en, this message translates to:
  /// **'Unclear alerts get a second reading from AI.'**
  String get aiSecondReading;

  /// No description provided for @readOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Read on your phone. Add an AI provider for tricky alerts.'**
  String get readOnPhone;

  /// No description provided for @aiSettings.
  ///
  /// In en, this message translates to:
  /// **'AI settings'**
  String get aiSettings;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @obligations.
  ///
  /// In en, this message translates to:
  /// **'Obligations'**
  String get obligations;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @pricesRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Prices refreshed'**
  String get pricesRefreshed;

  /// No description provided for @refreshPrices.
  ///
  /// In en, this message translates to:
  /// **'Refresh prices'**
  String get refreshPrices;

  /// No description provided for @couldNotLoadNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Could not load net worth.'**
  String get couldNotLoadNetWorth;

  /// No description provided for @netWorthCaps.
  ///
  /// In en, this message translates to:
  /// **'NET WORTH'**
  String get netWorthCaps;

  /// No description provided for @knownNetWorthCaps.
  ///
  /// In en, this message translates to:
  /// **'KNOWN NET WORTH'**
  String get knownNetWorthCaps;

  /// No description provided for @trendLineLater.
  ///
  /// In en, this message translates to:
  /// **'Your trend line appears after a few days of tracking.'**
  String get trendLineLater;

  /// No description provided for @assets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assets;

  /// No description provided for @debts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debts;

  /// No description provided for @liquid.
  ///
  /// In en, this message translates to:
  /// **'Liquid'**
  String get liquid;

  /// No description provided for @pricesMissing.
  ///
  /// In en, this message translates to:
  /// **'Some prices or exchange rates are missing. Totals include known values only.'**
  String get pricesMissing;

  /// No description provided for @pricesStale.
  ///
  /// In en, this message translates to:
  /// **'Some prices are more than 72 hours old. Pull down to refresh.'**
  String get pricesStale;

  /// No description provided for @reportingCurrency.
  ///
  /// In en, this message translates to:
  /// **'Reporting currency'**
  String get reportingCurrency;

  /// No description provided for @pageNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFoundTitle;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not Found'**
  String get notFound;

  /// No description provided for @destinationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This destination is unavailable or may have moved.'**
  String get destinationUnavailable;

  /// No description provided for @backHome.
  ///
  /// In en, this message translates to:
  /// **'Back Home'**
  String get backHome;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New Transaction'**
  String get newTransaction;

  /// No description provided for @noAccountsAddFirst.
  ///
  /// In en, this message translates to:
  /// **'No accounts available. Please add an account first.'**
  String get noAccountsAddFirst;

  /// No description provided for @needTwoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add at least 2 accounts to transfer.'**
  String get needTwoAccounts;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @amountReceivedIn.
  ///
  /// In en, this message translates to:
  /// **'Amount received in {currency}'**
  String amountReceivedIn(String currency);

  /// No description provided for @whatArrived.
  ///
  /// In en, this message translates to:
  /// **'What actually arrived after conversion'**
  String get whatArrived;

  /// No description provided for @transferFeeIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer fee in {currency} (optional)'**
  String transferFeeIn(String currency);

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @refundFor.
  ///
  /// In en, this message translates to:
  /// **'Refund for'**
  String get refundFor;

  /// No description provided for @merchantOptional.
  ///
  /// In en, this message translates to:
  /// **'Merchant or payee (optional)'**
  String get merchantOptional;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get addNote;

  /// No description provided for @addRefund.
  ///
  /// In en, this message translates to:
  /// **'Add Refund'**
  String get addRefund;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @addIncome.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get addIncome;

  /// No description provided for @paidWith.
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get paidWith;

  /// No description provided for @overCardLimit.
  ///
  /// In en, this message translates to:
  /// **'This goes over the card limit by {amount}.'**
  String overCardLimit(String amount);

  /// No description provided for @isRefund.
  ///
  /// In en, this message translates to:
  /// **'This is a refund'**
  String get isRefund;

  /// No description provided for @isRefundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money back that reduces spending'**
  String get isRefundSubtitle;

  /// No description provided for @paidOtherCurrency.
  ///
  /// In en, this message translates to:
  /// **'Paid in another currency'**
  String get paidOtherCurrency;

  /// No description provided for @paidOtherCurrencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'e.g. USD online or abroad, charged in {currency}'**
  String paidOtherCurrencySubtitle(String currency);

  /// No description provided for @priceIn.
  ///
  /// In en, this message translates to:
  /// **'Price in {currency}'**
  String priceIn(String currency);

  /// No description provided for @feeIncluded.
  ///
  /// In en, this message translates to:
  /// **'Charged amount already includes the bank fee'**
  String get feeIncluded;

  /// No description provided for @chargedAmountNote.
  ///
  /// In en, this message translates to:
  /// **'The amount above is what {account} was charged. Set a foreign transaction fee on the card to track it.'**
  String chargedAmountNote(String account);

  /// No description provided for @fxFeeInside.
  ///
  /// In en, this message translates to:
  /// **'Foreign transaction fee {percent}%: {fee} inside {charged}. Use the amount on your statement when you have it.'**
  String fxFeeInside(String percent, String fee, String charged);

  /// No description provided for @fxFeeOnTop.
  ///
  /// In en, this message translates to:
  /// **'Foreign transaction fee {percent}%: {fee} on top of {charged}. Use the amount on your statement when you have it.'**
  String fxFeeOnTop(String percent, String fee, String charged);

  /// No description provided for @selectAccountError.
  ///
  /// In en, this message translates to:
  /// **'Please select an account'**
  String get selectAccountError;

  /// No description provided for @selectDestinationError.
  ///
  /// In en, this message translates to:
  /// **'Please select destination account'**
  String get selectDestinationError;

  /// No description provided for @sameAccountsError.
  ///
  /// In en, this message translates to:
  /// **'Transfer source and destination must be different'**
  String get sameAccountsError;

  /// No description provided for @selectCategoryError.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get selectCategoryError;

  /// No description provided for @chooseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose a currency'**
  String get chooseCurrency;

  /// No description provided for @transferEditNote.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to both linked accounts and the transfer fee.'**
  String get transferEditNote;

  /// No description provided for @editTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get editTransfer;

  /// No description provided for @deleteTransfer.
  ///
  /// In en, this message translates to:
  /// **'Delete transfer'**
  String get deleteTransfer;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// No description provided for @refundReduces.
  ///
  /// In en, this message translates to:
  /// **'Refund · reduces spending in its category'**
  String get refundReduces;

  /// No description provided for @editLinkedTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit linked transfer'**
  String get editLinkedTransfer;

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get toAccount;

  /// No description provided for @sourceAmount.
  ///
  /// In en, this message translates to:
  /// **'Source amount'**
  String get sourceAmount;

  /// No description provided for @destinationAmount.
  ///
  /// In en, this message translates to:
  /// **'Destination amount'**
  String get destinationAmount;

  /// No description provided for @sourceCurrencyFee.
  ///
  /// In en, this message translates to:
  /// **'Source-currency fee'**
  String get sourceCurrencyFee;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @deleteTransactionTitle2.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction'**
  String get deleteTransactionTitle2;

  /// No description provided for @deleteTransactionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? The account balance will be adjusted.'**
  String get deleteTransactionConfirm;

  /// No description provided for @paidOriginal.
  ///
  /// In en, this message translates to:
  /// **'Paid {currency} {amount}.'**
  String paidOriginal(String currency, String amount);

  /// No description provided for @paidOriginalWithFee.
  ///
  /// In en, this message translates to:
  /// **'Paid {currency} {amount}; the {percent}% foreign transaction fee follows this amount.'**
  String paidOriginalWithFee(String currency, String amount, String percent);

  /// No description provided for @noRateForDate.
  ///
  /// In en, this message translates to:
  /// **'No {from}→{to} rate for this date. Enter the amount in {to}.'**
  String noRateForDate(String from, String to);

  /// No description provided for @convertedAtRate.
  ///
  /// In en, this message translates to:
  /// **'Converted {from} {amount} to {to} at the rate for this date. Check it matches what was charged.'**
  String convertedAtRate(String from, String amount, String to);

  /// No description provided for @recurringPayment.
  ///
  /// In en, this message translates to:
  /// **'Recurring payment'**
  String get recurringPayment;

  /// No description provided for @recurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring Transactions'**
  String get recurringTransactions;

  /// No description provided for @noRecurring.
  ///
  /// In en, this message translates to:
  /// **'No recurring transactions'**
  String get noRecurring;

  /// No description provided for @setUpAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Set up automatic transactions'**
  String get setUpAutomatic;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading'**
  String get errorLoading;

  /// No description provided for @pausedCaps.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get pausedCaps;

  /// No description provided for @frequencyNext.
  ///
  /// In en, this message translates to:
  /// **'{frequency} · next {date}'**
  String frequencyNext(String frequency, String date);

  /// No description provided for @notPosted.
  ///
  /// In en, this message translates to:
  /// **'Not posted: {reason}'**
  String notPosted(String reason);

  /// No description provided for @recurringOptions.
  ///
  /// In en, this message translates to:
  /// **'Recurring options'**
  String get recurringOptions;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @newRecurring.
  ///
  /// In en, this message translates to:
  /// **'New Recurring Transaction'**
  String get newRecurring;

  /// No description provided for @editRecurring.
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring Transaction'**
  String get editRecurring;

  /// No description provided for @toAccountHint.
  ///
  /// In en, this message translates to:
  /// **'To account (e.g. your credit card or savings)'**
  String get toAccountHint;

  /// No description provided for @chargedTo.
  ///
  /// In en, this message translates to:
  /// **'Charged to'**
  String get chargedTo;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @firstOccurrence.
  ///
  /// In en, this message translates to:
  /// **'First Occurrence'**
  String get firstOccurrence;

  /// No description provided for @nextOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Next Occurrence'**
  String get nextOccurrence;

  /// No description provided for @endsOptional.
  ///
  /// In en, this message translates to:
  /// **'Ends (optional)'**
  String get endsOptional;

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDate;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @createRecurring.
  ///
  /// In en, this message translates to:
  /// **'Create Recurring'**
  String get createRecurring;

  /// No description provided for @chooseTransferTarget.
  ///
  /// In en, this message translates to:
  /// **'Choose the account to transfer to'**
  String get chooseTransferTarget;

  /// No description provided for @selectAccountCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select account and category'**
  String get selectAccountCategory;

  /// No description provided for @startInPast.
  ///
  /// In en, this message translates to:
  /// **'Start date is in the past'**
  String get startInPast;

  /// No description provided for @tooManyMissed.
  ///
  /// In en, this message translates to:
  /// **'More than 24 payments fall before today. The schedule will start from its next date; add older payments manually if you need them.'**
  String get tooManyMissed;

  /// No description provided for @missedPayments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment falls before today. Post it now, or start from the next date?} other{{count} payments fall before today. Post them now, or start from the next date?}}'**
  String missedPayments(int count);

  /// No description provided for @startFromNext.
  ///
  /// In en, this message translates to:
  /// **'Start from next date'**
  String get startFromNext;

  /// No description provided for @postCount.
  ///
  /// In en, this message translates to:
  /// **'Post {count}'**
  String postCount(int count);

  /// No description provided for @noBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets set'**
  String get noBudgets;

  /// No description provided for @noBudgetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a budget to track your spending limits.'**
  String get noBudgetsSubtitle;

  /// No description provided for @createABudget.
  ///
  /// In en, this message translates to:
  /// **'Create a budget'**
  String get createABudget;

  /// No description provided for @activeBudgets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ACTIVE BUDGET} other{{count} ACTIVE BUDGETS}}'**
  String activeBudgets(int count);

  /// No description provided for @errorLoadingBudgets.
  ///
  /// In en, this message translates to:
  /// **'Error loading budgets'**
  String get errorLoadingBudgets;

  /// No description provided for @deleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Delete Budget'**
  String get deleteBudget;

  /// No description provided for @deleteBudgetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this budget?'**
  String get deleteBudgetConfirm;

  /// No description provided for @budgetUsedPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of budget used'**
  String budgetUsedPercent(String percent);

  /// No description provided for @budgetOptions.
  ///
  /// In en, this message translates to:
  /// **'Budget options'**
  String get budgetOptions;

  /// No description provided for @budgetConfirmCurrency.
  ///
  /// In en, this message translates to:
  /// **'Budget {amount} · confirm its original currency using Edit.'**
  String budgetConfirmCurrency(String amount);

  /// No description provided for @overBy.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String overBy(String amount);

  /// No description provided for @remainingUsed.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining · {percent}% used'**
  String remainingUsed(String amount, String percent);

  /// No description provided for @recordsNeedRates.
  ///
  /// In en, this message translates to:
  /// **'{count} records need exchange rates; spending is incomplete.'**
  String recordsNeedRates(int count);

  /// No description provided for @previousBudgetPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous budget period'**
  String get previousBudgetPeriod;

  /// No description provided for @nextBudgetPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next budget period'**
  String get nextBudgetPeriod;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudget;

  /// No description provided for @originalBudgetCurrency.
  ///
  /// In en, this message translates to:
  /// **'Original budget currency'**
  String get originalBudgetCurrency;

  /// No description provided for @budgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget amount'**
  String get budgetAmount;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @createBudget.
  ///
  /// In en, this message translates to:
  /// **'Create Budget'**
  String get createBudget;

  /// No description provided for @budgetAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Amount'**
  String get budgetAmountTitle;

  /// No description provided for @budgetExists.
  ///
  /// In en, this message translates to:
  /// **'This category already has a {period} budget. Edit it instead.'**
  String budgetExists(String period);

  /// No description provided for @cardPaymentNote.
  ///
  /// In en, this message translates to:
  /// **'Card payment: {name}'**
  String cardPaymentNote(String name);

  /// No description provided for @cardInterest.
  ///
  /// In en, this message translates to:
  /// **'Card interest'**
  String get cardInterest;

  /// No description provided for @annualCardFee.
  ///
  /// In en, this message translates to:
  /// **'Annual card fee'**
  String get annualCardFee;

  /// No description provided for @cardFee.
  ///
  /// In en, this message translates to:
  /// **'Card fee'**
  String get cardFee;

  /// No description provided for @charge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get charge;

  /// No description provided for @interest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interest;

  /// No description provided for @latePaymentFee.
  ///
  /// In en, this message translates to:
  /// **'Late payment fee'**
  String get latePaymentFee;

  /// No description provided for @annualFee.
  ///
  /// In en, this message translates to:
  /// **'Annual fee'**
  String get annualFee;

  /// No description provided for @otherBankFee.
  ///
  /// In en, this message translates to:
  /// **'Other bank fee'**
  String get otherBankFee;

  /// No description provided for @cardDetails.
  ///
  /// In en, this message translates to:
  /// **'Card details'**
  String get cardDetails;

  /// No description provided for @cardDetailsHelp.
  ///
  /// In en, this message translates to:
  /// **'Add the limit, statement and due days and fees to see available credit, the minimum payment and interest.'**
  String get cardDetailsHelp;

  /// No description provided for @setUpCardTerms.
  ///
  /// In en, this message translates to:
  /// **'Set up card terms'**
  String get setUpCardTerms;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get credit;

  /// No description provided for @editCardTerms.
  ///
  /// In en, this message translates to:
  /// **'Edit card terms'**
  String get editCardTerms;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @limit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limit;

  /// No description provided for @limitUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the limit used'**
  String limitUsed(String percent);

  /// No description provided for @under30Tip.
  ///
  /// In en, this message translates to:
  /// **'keeping it under 30% helps your credit'**
  String get under30Tip;

  /// No description provided for @overLimitBy.
  ///
  /// In en, this message translates to:
  /// **'Over the limit by {amount}'**
  String overLimitBy(String amount);

  /// No description provided for @lastStatement.
  ///
  /// In en, this message translates to:
  /// **'Last statement'**
  String get lastStatement;

  /// No description provided for @stillToPay.
  ///
  /// In en, this message translates to:
  /// **'Still to pay'**
  String get stillToPay;

  /// No description provided for @minimumDue.
  ///
  /// In en, this message translates to:
  /// **'Minimum due'**
  String get minimumDue;

  /// No description provided for @minimumDueBy.
  ///
  /// In en, this message translates to:
  /// **'Minimum due by {date}'**
  String minimumDueBy(String date);

  /// No description provided for @interestIfUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Interest if unpaid (est.)'**
  String get interestIfUnpaid;

  /// No description provided for @cashAdvances.
  ///
  /// In en, this message translates to:
  /// **'Cash advances'**
  String get cashAdvances;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Pay card'**
  String get payCard;

  /// No description provided for @interestOrFee.
  ///
  /// In en, this message translates to:
  /// **'Interest or fee'**
  String get interestOrFee;

  /// No description provided for @termsOf.
  ///
  /// In en, this message translates to:
  /// **'{name} terms'**
  String termsOf(String name);

  /// No description provided for @creditLimitIn.
  ///
  /// In en, this message translates to:
  /// **'Credit limit ({currency})'**
  String creditLimitIn(String currency);

  /// No description provided for @purchaseInterest.
  ///
  /// In en, this message translates to:
  /// **'Purchase interest, % a year'**
  String get purchaseInterest;

  /// No description provided for @statementClosingDay.
  ///
  /// In en, this message translates to:
  /// **'Statement closing day (1–31)'**
  String get statementClosingDay;

  /// No description provided for @paymentDueDay.
  ///
  /// In en, this message translates to:
  /// **'Payment due day (1–31)'**
  String get paymentDueDay;

  /// No description provided for @minimumPaymentPercent.
  ///
  /// In en, this message translates to:
  /// **'Minimum payment, % of statement'**
  String get minimumPaymentPercent;

  /// No description provided for @minimumPaymentAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Minimum payment at least ({currency})'**
  String minimumPaymentAtLeast(String currency);

  /// No description provided for @foreignFeePercent.
  ///
  /// In en, this message translates to:
  /// **'Foreign transaction fee, %'**
  String get foreignFeePercent;

  /// No description provided for @cashAdvanceFee.
  ///
  /// In en, this message translates to:
  /// **'Cash advance fee, %'**
  String get cashAdvanceFee;

  /// No description provided for @cashAdvanceFeeMin.
  ///
  /// In en, this message translates to:
  /// **'Cash advance fee at least ({currency})'**
  String cashAdvanceFeeMin(String currency);

  /// No description provided for @cashAdvanceInterest.
  ///
  /// In en, this message translates to:
  /// **'Cash advance interest, % a year'**
  String get cashAdvanceInterest;

  /// No description provided for @latePaymentFeeIn.
  ///
  /// In en, this message translates to:
  /// **'Late payment fee ({currency})'**
  String latePaymentFeeIn(String currency);

  /// No description provided for @addAccountToPayFrom.
  ///
  /// In en, this message translates to:
  /// **'Add a {currency} bank or cash account to pay from'**
  String addAccountToPayFrom(String currency);

  /// No description provided for @payNamed.
  ///
  /// In en, this message translates to:
  /// **'Pay {name}'**
  String payNamed(String name);

  /// No description provided for @payFrom.
  ///
  /// In en, this message translates to:
  /// **'Pay from'**
  String get payFrom;

  /// No description provided for @amountMinimum.
  ///
  /// In en, this message translates to:
  /// **'Amount (minimum {amount})'**
  String amountMinimum(String amount);

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @chargeOn.
  ///
  /// In en, this message translates to:
  /// **'Charge on {name}'**
  String chargeOn(String name);

  /// No description provided for @amountIn.
  ///
  /// In en, this message translates to:
  /// **'Amount ({currency})'**
  String amountIn(String currency);

  /// No description provided for @statementDate.
  ///
  /// In en, this message translates to:
  /// **'Statement date'**
  String get statementDate;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @setPrice.
  ///
  /// In en, this message translates to:
  /// **'Set price'**
  String get setPrice;

  /// No description provided for @useFeed.
  ///
  /// In en, this message translates to:
  /// **'Use feed'**
  String get useFeed;

  /// No description provided for @linkMortgage.
  ///
  /// In en, this message translates to:
  /// **'Link mortgage'**
  String get linkMortgage;

  /// No description provided for @adjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get adjust;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @actualIncomeInAccount.
  ///
  /// In en, this message translates to:
  /// **'Actual income in account currency'**
  String get actualIncomeInAccount;

  /// No description provided for @pricePerUnitIn.
  ///
  /// In en, this message translates to:
  /// **'Price per unit in {currency}'**
  String pricePerUnitIn(String currency);

  /// No description provided for @addHolding.
  ///
  /// In en, this message translates to:
  /// **'Add holding'**
  String get addHolding;

  /// No description provided for @addHoldingHelp.
  ///
  /// In en, this message translates to:
  /// **'Add gold, investments, property, crypto, or another asset. Existing holdings do not change your cash balance.'**
  String get addHoldingHelp;

  /// No description provided for @missingPrice.
  ///
  /// In en, this message translates to:
  /// **'Missing price'**
  String get missingPrice;

  /// No description provided for @needsPrice.
  ///
  /// In en, this message translates to:
  /// **'Needs price'**
  String get needsPrice;

  /// No description provided for @costUnknown.
  ///
  /// In en, this message translates to:
  /// **'Cost {amount} {currency}'**
  String costUnknown(String amount, String currency);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknown;

  /// No description provided for @assetName.
  ///
  /// In en, this message translates to:
  /// **'Asset name'**
  String get assetName;

  /// No description provided for @assetClass.
  ///
  /// In en, this message translates to:
  /// **'Asset class'**
  String get assetClass;

  /// No description provided for @quantityGrams.
  ///
  /// In en, this message translates to:
  /// **'Quantity / weight in grams'**
  String get quantityGrams;

  /// No description provided for @acquisitionCurrency.
  ///
  /// In en, this message translates to:
  /// **'Acquisition currency'**
  String get acquisitionCurrency;

  /// No description provided for @totalCostShare.
  ///
  /// In en, this message translates to:
  /// **'Total cost of your share (blank if unknown)'**
  String get totalCostShare;

  /// No description provided for @tickerSymbol.
  ///
  /// In en, this message translates to:
  /// **'Ticker / crypto symbol'**
  String get tickerSymbol;

  /// No description provided for @exchangeHint.
  ///
  /// In en, this message translates to:
  /// **'Exchange (EGX, NASDAQ, etc.)'**
  String get exchangeHint;

  /// No description provided for @whereHeld.
  ///
  /// In en, this message translates to:
  /// **'Where it is held'**
  String get whereHeld;

  /// No description provided for @ownershipFraction.
  ///
  /// In en, this message translates to:
  /// **'Ownership fraction (1 = 100%)'**
  String get ownershipFraction;

  /// No description provided for @goldKarat.
  ///
  /// In en, this message translates to:
  /// **'Gold karat'**
  String get goldKarat;

  /// No description provided for @priceSource.
  ///
  /// In en, this message translates to:
  /// **'Price source'**
  String get priceSource;

  /// No description provided for @datedManualPrices.
  ///
  /// In en, this message translates to:
  /// **'Dated manual prices'**
  String get datedManualPrices;

  /// No description provided for @freeMarketFeed.
  ///
  /// In en, this message translates to:
  /// **'Free market feed when supported'**
  String get freeMarketFeed;

  /// No description provided for @currentResalePrice.
  ///
  /// In en, this message translates to:
  /// **'Current unit / gram resale price (optional)'**
  String get currentResalePrice;

  /// No description provided for @openingDate.
  ///
  /// In en, this message translates to:
  /// **'Opening date'**
  String get openingDate;

  /// No description provided for @priceMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Price must be positive'**
  String get priceMustBePositive;

  /// No description provided for @valueNamed.
  ///
  /// In en, this message translates to:
  /// **'Value {name}'**
  String valueNamed(String name);

  /// No description provided for @resalePricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Resale price per unit / gram'**
  String get resalePricePerUnit;

  /// No description provided for @quoteCurrency.
  ///
  /// In en, this message translates to:
  /// **'Quote currency'**
  String get quoteCurrency;

  /// No description provided for @quoteDate.
  ///
  /// In en, this message translates to:
  /// **'Quote date'**
  String get quoteDate;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @ownershipLine.
  ///
  /// In en, this message translates to:
  /// **'{quantity} {unit} · ownership {percent}%'**
  String ownershipLine(String quantity, String unit, String percent);

  /// No description provided for @unrealizedGainCaps.
  ///
  /// In en, this message translates to:
  /// **'UNREALIZED GAIN'**
  String get unrealizedGainCaps;

  /// No description provided for @gainUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown — cost or price unavailable'**
  String get gainUnknown;

  /// No description provided for @linkPropertyMortgage.
  ///
  /// In en, this message translates to:
  /// **'Link property and mortgage'**
  String get linkPropertyMortgage;

  /// No description provided for @existingObligation.
  ///
  /// In en, this message translates to:
  /// **'Existing obligation (counted once in net worth)'**
  String get existingObligation;

  /// No description provided for @noLinkedMortgage.
  ///
  /// In en, this message translates to:
  /// **'No linked mortgage'**
  String get noLinkedMortgage;

  /// No description provided for @manualAppraisals.
  ///
  /// In en, this message translates to:
  /// **'This asset uses dated manual appraisals.'**
  String get manualAppraisals;

  /// No description provided for @adjustHoldingAudit.
  ///
  /// In en, this message translates to:
  /// **'Adjust holding with an audit record'**
  String get adjustHoldingAudit;

  /// No description provided for @correctQuantity.
  ///
  /// In en, this message translates to:
  /// **'Correct quantity'**
  String get correctQuantity;

  /// No description provided for @totalAcquisitionCost.
  ///
  /// In en, this message translates to:
  /// **'Total acquisition cost (blank if unknown)'**
  String get totalAcquisitionCost;

  /// No description provided for @custodyLocation.
  ///
  /// In en, this message translates to:
  /// **'Custody / location'**
  String get custodyLocation;

  /// No description provided for @adjustReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for adjustment'**
  String get adjustReason;

  /// No description provided for @stockSplit.
  ///
  /// In en, this message translates to:
  /// **'Stock split / quantity adjustment'**
  String get stockSplit;

  /// No description provided for @newUnitsPerOld.
  ///
  /// In en, this message translates to:
  /// **'New units per old unit'**
  String get newUnitsPerOld;

  /// No description provided for @createCashAccountFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a cash account first'**
  String get createCashAccountFirst;

  /// No description provided for @cashAccount.
  ///
  /// In en, this message translates to:
  /// **'Cash account'**
  String get cashAccount;

  /// No description provided for @incomeType.
  ///
  /// In en, this message translates to:
  /// **'Income type'**
  String get incomeType;

  /// No description provided for @dividend.
  ///
  /// In en, this message translates to:
  /// **'Dividend'**
  String get dividend;

  /// No description provided for @rent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get rent;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @actualGrossCash.
  ///
  /// In en, this message translates to:
  /// **'Actual gross cash in account currency (optional)'**
  String get actualGrossCash;

  /// No description provided for @feeInAccount.
  ///
  /// In en, this message translates to:
  /// **'Fee in account currency'**
  String get feeInAccount;

  /// No description provided for @transactionDate.
  ///
  /// In en, this message translates to:
  /// **'Transaction date'**
  String get transactionDate;

  /// No description provided for @activityOf.
  ///
  /// In en, this message translates to:
  /// **'{name} activity'**
  String activityOf(String name);

  /// No description provided for @unknownCost.
  ///
  /// In en, this message translates to:
  /// **'Unknown cost'**
  String get unknownCost;

  /// No description provided for @gainLabel.
  ///
  /// In en, this message translates to:
  /// **'Gain {amount}'**
  String gainLabel(String amount);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @assetGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get assetGold;

  /// No description provided for @assetStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get assetStock;

  /// No description provided for @assetFund.
  ///
  /// In en, this message translates to:
  /// **'Fund'**
  String get assetFund;

  /// No description provided for @assetCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get assetCrypto;

  /// No description provided for @assetProperty.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get assetProperty;

  /// No description provided for @assetCustom.
  ///
  /// In en, this message translates to:
  /// **'Other asset'**
  String get assetCustom;

  /// No description provided for @ratesMatures.
  ///
  /// In en, this message translates to:
  /// **'{rate}% · matures {date}'**
  String ratesMatures(String rate, String date);

  /// No description provided for @contractDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get contractDeposit;

  /// No description provided for @contractCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get contractCertificate;

  /// No description provided for @contractLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get contractLoan;

  /// No description provided for @contractReceivable.
  ///
  /// In en, this message translates to:
  /// **'Money owed to you'**
  String get contractReceivable;

  /// No description provided for @contractCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get contractCreditCard;

  /// No description provided for @addContractOrDebt.
  ///
  /// In en, this message translates to:
  /// **'Add contract or debt'**
  String get addContractOrDebt;

  /// No description provided for @expectedPaymentsNote.
  ///
  /// In en, this message translates to:
  /// **'Expected payments never change cash until you confirm receipt or payment.'**
  String get expectedPaymentsNote;

  /// No description provided for @owed.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get owed;

  /// No description provided for @principal.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get principal;

  /// No description provided for @addContractObligation.
  ///
  /// In en, this message translates to:
  /// **'Add contract or obligation'**
  String get addContractObligation;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @existingPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Existing outstanding / invested principal'**
  String get existingPrincipal;

  /// No description provided for @annualInterestCoupon.
  ///
  /// In en, this message translates to:
  /// **'Annual interest / coupon (%)'**
  String get annualInterestCoupon;

  /// No description provided for @counterparty.
  ///
  /// In en, this message translates to:
  /// **'Bank / person / lender'**
  String get counterparty;

  /// No description provided for @interestConvention.
  ///
  /// In en, this message translates to:
  /// **'Interest convention'**
  String get interestConvention;

  /// No description provided for @flatRate.
  ///
  /// In en, this message translates to:
  /// **'Flat fixed annual rate / periodic coupons'**
  String get flatRate;

  /// No description provided for @reducingBalance.
  ///
  /// In en, this message translates to:
  /// **'Reducing balance, equal installments'**
  String get reducingBalance;

  /// No description provided for @manualSchedule.
  ///
  /// In en, this message translates to:
  /// **'Enter an agreed schedule manually'**
  String get manualSchedule;

  /// No description provided for @paymentsPerYear.
  ///
  /// In en, this message translates to:
  /// **'Payments per year'**
  String get paymentsPerYear;

  /// No description provided for @quarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get quarterly;

  /// No description provided for @halfYearly.
  ///
  /// In en, this message translates to:
  /// **'Half-yearly'**
  String get halfYearly;

  /// No description provided for @maturityDate.
  ///
  /// In en, this message translates to:
  /// **'Maturity / end date'**
  String get maturityDate;

  /// No description provided for @payoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Cash / payout account'**
  String get payoutAccount;

  /// No description provided for @linkedCard.
  ///
  /// In en, this message translates to:
  /// **'Linked credit card (cards only)'**
  String get linkedCard;

  /// No description provided for @cardStatementDay.
  ///
  /// In en, this message translates to:
  /// **'Card statement day'**
  String get cardStatementDay;

  /// No description provided for @cardPaymentDay.
  ///
  /// In en, this message translates to:
  /// **'Card payment day'**
  String get cardPaymentDay;

  /// No description provided for @movePrincipalNow.
  ///
  /// In en, this message translates to:
  /// **'Move principal from/to cash now?'**
  String get movePrincipalNow;

  /// No description provided for @existingPosition.
  ///
  /// In en, this message translates to:
  /// **'No — this is an existing position'**
  String get existingPosition;

  /// No description provided for @recordNewFunding.
  ///
  /// In en, this message translates to:
  /// **'Yes — record new funding'**
  String get recordNewFunding;

  /// No description provided for @cardDaysRange.
  ///
  /// In en, this message translates to:
  /// **'Card days must be 1–31'**
  String get cardDaysRange;

  /// No description provided for @principalAnnual.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency} · {rate}% annual'**
  String principalAnnual(String amount, String currency, String rate);

  /// No description provided for @equalInstallmentsNote.
  ///
  /// In en, this message translates to:
  /// **'Equal installments; periodic rate = annual rate / payments per year.'**
  String get equalInstallmentsNote;

  /// No description provided for @flatCouponsNote.
  ///
  /// In en, this message translates to:
  /// **'Flat coupons; final partial period is prorated by actual days in the scheduled period.'**
  String get flatCouponsNote;

  /// No description provided for @outstandingAmount.
  ///
  /// In en, this message translates to:
  /// **'Outstanding {amount} {currency}'**
  String outstandingAmount(String amount, String currency);

  /// No description provided for @billedLine.
  ///
  /// In en, this message translates to:
  /// **'Billed {billed} · unbilled {unbilled}\nOlder / opening {older} · due {due}'**
  String billedLine(String billed, String unbilled, String older, String due);

  /// No description provided for @addAgreedPayment.
  ///
  /// In en, this message translates to:
  /// **'Add agreed payment'**
  String get addAgreedPayment;

  /// No description provided for @earlySettlement.
  ///
  /// In en, this message translates to:
  /// **'Early settlement'**
  String get earlySettlement;

  /// No description provided for @outstandingPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Outstanding principal'**
  String get outstandingPrincipal;

  /// No description provided for @agreedFinalInterest.
  ///
  /// In en, this message translates to:
  /// **'Agreed final interest / fee'**
  String get agreedFinalInterest;

  /// No description provided for @noLinkedCashAccount.
  ///
  /// In en, this message translates to:
  /// **'No linked cash account'**
  String get noLinkedCashAccount;

  /// No description provided for @recordEarlySettlement.
  ///
  /// In en, this message translates to:
  /// **'Record early settlement'**
  String get recordEarlySettlement;

  /// No description provided for @principalInterestLine.
  ///
  /// In en, this message translates to:
  /// **'Principal {principal} · interest {interest}'**
  String principalInterestLine(String principal, String interest);

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @reverseConfirmedPayment.
  ///
  /// In en, this message translates to:
  /// **'Reverse confirmed payment'**
  String get reverseConfirmedPayment;

  /// No description provided for @reversePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse payment?'**
  String get reversePaymentTitle;

  /// No description provided for @reversePaymentBody.
  ///
  /// In en, this message translates to:
  /// **'This reverses the linked cash entries and marks the payment unpaid.'**
  String get reversePaymentBody;

  /// No description provided for @reverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get reverse;

  /// No description provided for @confirmActual.
  ///
  /// In en, this message translates to:
  /// **'Confirm actual {amount} {currency}'**
  String confirmActual(String amount, String currency);

  /// No description provided for @cashAccountRecordNow.
  ///
  /// In en, this message translates to:
  /// **'Cash account · record actual payment now'**
  String get cashAccountRecordNow;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @payCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Pay credit card'**
  String get payCreditCard;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @principalAmount.
  ///
  /// In en, this message translates to:
  /// **'Principal amount'**
  String get principalAmount;

  /// No description provided for @interestAmount.
  ///
  /// In en, this message translates to:
  /// **'Interest amount'**
  String get interestAmount;

  /// No description provided for @enterPositivePayment.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive payment'**
  String get enterPositivePayment;

  /// No description provided for @notRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get notRecorded;

  /// No description provided for @feesForeign.
  ///
  /// In en, this message translates to:
  /// **'Foreign transaction fees'**
  String get feesForeign;

  /// No description provided for @feesTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer fees'**
  String get feesTransfer;

  /// No description provided for @feesCashAdvance.
  ///
  /// In en, this message translates to:
  /// **'Cash advance fees'**
  String get feesCashAdvance;

  /// No description provided for @feesLate.
  ///
  /// In en, this message translates to:
  /// **'Late payment fees'**
  String get feesLate;

  /// No description provided for @feesAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual card fees'**
  String get feesAnnual;

  /// No description provided for @feesInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment fees'**
  String get feesInvestment;

  /// No description provided for @feesOther.
  ///
  /// In en, this message translates to:
  /// **'Other bank fees'**
  String get feesOther;

  /// No description provided for @percentVsLast.
  ///
  /// In en, this message translates to:
  /// **'{percent}% vs last'**
  String percentVsLast(String percent);

  /// No description provided for @priceFxGain.
  ///
  /// In en, this message translates to:
  /// **'Price {price} · FX {fx}'**
  String priceFxGain(String price, String fx);

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @spendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get spendingByCategory;

  /// No description provided for @noSpendingMonth.
  ///
  /// In en, this message translates to:
  /// **'No spending this month.'**
  String get noSpendingMonth;

  /// No description provided for @totalCaps.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get totalCaps;

  /// No description provided for @howYouPaid.
  ///
  /// In en, this message translates to:
  /// **'How you paid'**
  String get howYouPaid;

  /// No description provided for @byCardOrWallet.
  ///
  /// In en, this message translates to:
  /// **'By card or wallet'**
  String get byCardOrWallet;

  /// No description provided for @spendingByCurrency.
  ///
  /// In en, this message translates to:
  /// **'Spending by currency'**
  String get spendingByCurrency;

  /// No description provided for @convertedAtEachDate.
  ///
  /// In en, this message translates to:
  /// **'Converted to your reporting currency at each date.'**
  String get convertedAtEachDate;

  /// No description provided for @feesInterestPaid.
  ///
  /// In en, this message translates to:
  /// **'Fees and interest paid'**
  String get feesInterestPaid;

  /// No description provided for @incomeSources.
  ///
  /// In en, this message translates to:
  /// **'Income sources'**
  String get incomeSources;

  /// No description provided for @noIncomeMonth.
  ///
  /// In en, this message translates to:
  /// **'No income this month.'**
  String get noIncomeMonth;

  /// No description provided for @assetAllocation.
  ///
  /// In en, this message translates to:
  /// **'Asset allocation'**
  String get assetAllocation;

  /// No description provided for @noValuedAssets.
  ///
  /// In en, this message translates to:
  /// **'No valued assets yet.'**
  String get noValuedAssets;

  /// No description provided for @currencyExposure.
  ///
  /// In en, this message translates to:
  /// **'Currency exposure'**
  String get currencyExposure;

  /// No description provided for @originalAmounts.
  ///
  /// In en, this message translates to:
  /// **'Original amounts, before conversion.'**
  String get originalAmounts;

  /// No description provided for @holdingGains.
  ///
  /// In en, this message translates to:
  /// **'Holding gains since opening'**
  String get holdingGains;

  /// No description provided for @holdingGainsNote.
  ///
  /// In en, this message translates to:
  /// **'Price gains and the FX effect on acquisition cost are separate. Missing acquisition history stays unknown.'**
  String get holdingGainsNote;

  /// No description provided for @noGainsYet.
  ///
  /// In en, this message translates to:
  /// **'No gains recorded yet.'**
  String get noGainsYet;

  /// No description provided for @netWorthHistory.
  ///
  /// In en, this message translates to:
  /// **'Net worth history'**
  String get netWorthHistory;

  /// No description provided for @netWorthHistoryNote.
  ///
  /// In en, this message translates to:
  /// **'Recorded observations only. No values are invented before tracking began.'**
  String get netWorthHistoryNote;

  /// No description provided for @chartAppearsLater.
  ///
  /// In en, this message translates to:
  /// **'The chart appears after a few days of tracking.'**
  String get chartAppearsLater;

  /// No description provided for @expectedCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Expected cash flow · next 30 days'**
  String get expectedCashFlow;

  /// No description provided for @expectedCashFlowNote.
  ///
  /// In en, this message translates to:
  /// **'Based on unconfirmed contract schedules. This is a projection, not available cash.'**
  String get expectedCashFlowNote;

  /// No description provided for @realizedGains.
  ///
  /// In en, this message translates to:
  /// **'Realized investment gains'**
  String get realizedGains;

  /// No description provided for @noRealizedGains.
  ///
  /// In en, this message translates to:
  /// **'No realized gains yet.'**
  String get noRealizedGains;

  /// No description provided for @bankWalletApps.
  ///
  /// In en, this message translates to:
  /// **'Bank and wallet apps'**
  String get bankWalletApps;

  /// No description provided for @searchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get searchApps;

  /// No description provided for @noAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No apps found.'**
  String get noAppsFound;

  /// No description provided for @noMatchingApps.
  ///
  /// In en, this message translates to:
  /// **'No matching apps.'**
  String get noMatchingApps;

  /// No description provided for @readAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Read payment alerts?'**
  String get readAlertsTitle;

  /// No description provided for @readAlertsBody.
  ///
  /// In en, this message translates to:
  /// **'Flourish will read notifications from your messaging app and the bank or wallet apps you choose, to find payment alerts (amount, merchant, card ending). Other notifications are ignored on the spot. One-time codes and declined payments are never saved, card numbers are reduced to their last 4 digits, and nothing leaves your phone. You review every payment before it is added, unless you turn on automatic adding.'**
  String get readAlertsBody;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @detectFromNotifications.
  ///
  /// In en, this message translates to:
  /// **'Detect payments from notifications'**
  String get detectFromNotifications;

  /// No description provided for @detectFromNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bank SMS and bank or wallet app alerts go to your inbox'**
  String get detectFromNotificationsSubtitle;

  /// No description provided for @accessGranted.
  ///
  /// In en, this message translates to:
  /// **'Notification access granted'**
  String get accessGranted;

  /// No description provided for @accessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Notification access needed'**
  String get accessNeeded;

  /// No description provided for @restrictedSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'If the switch is greyed out, open App info › ⋮ › Allow restricted settings first.'**
  String get restrictedSettingsHint;

  /// No description provided for @grant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get grant;

  /// No description provided for @messagingAlwaysRead.
  ///
  /// In en, this message translates to:
  /// **'Messaging apps are always read. Apps that posted money-like notifications appear here; tick the ones from your bank or wallet, or choose them from your installed apps.'**
  String get messagingAlwaysRead;

  /// No description provided for @noneSeenYet.
  ///
  /// In en, this message translates to:
  /// **'None seen yet. They appear after the next alert.'**
  String get noneSeenYet;

  /// No description provided for @alertsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} alerts'**
  String alertsCount(int count);

  /// No description provided for @chosenFromInstalled.
  ///
  /// In en, this message translates to:
  /// **'Chosen from installed apps'**
  String get chosenFromInstalled;

  /// No description provided for @chooseFromInstalled.
  ///
  /// In en, this message translates to:
  /// **'Choose from installed apps'**
  String get chooseFromInstalled;

  /// No description provided for @notifyNewPayments.
  ///
  /// In en, this message translates to:
  /// **'Notify me about new payments'**
  String get notifyNewPayments;

  /// No description provided for @iosShortcutsIntro.
  ///
  /// In en, this message translates to:
  /// **'iOS does not let apps read messages, so Shortcuts sends them to Flourish. Set this up once (iOS 17 or later):'**
  String get iosShortcutsIntro;

  /// No description provided for @iosStep1.
  ///
  /// In en, this message translates to:
  /// **'Open Shortcuts › Automation › New Automation › Message.'**
  String get iosStep1;

  /// No description provided for @iosStep2.
  ///
  /// In en, this message translates to:
  /// **'Message Contains: EGP. Choose Run Immediately. Make one more automation for each word your bank uses: جنيه, ج.م, and the currencies you pay in abroad or online, such as USD, دولار, EUR, SAR.'**
  String get iosStep2;

  /// No description provided for @iosStep3.
  ///
  /// In en, this message translates to:
  /// **'Add the action \"Import Transaction Text\" from Flourish and pass it the Message and Sender.'**
  String get iosStep3;

  /// No description provided for @iosStep4.
  ///
  /// In en, this message translates to:
  /// **'For Apple Pay: New Automation › Wallet › choose your cards › Run Immediately › \"Log Card Payment\" with Amount, Merchant and Card.'**
  String get iosStep4;

  /// No description provided for @paymentsArriveInbox.
  ///
  /// In en, this message translates to:
  /// **'Payments arrive in your inbox without opening Flourish.'**
  String get paymentsArriveInbox;

  /// No description provided for @addingPayments.
  ///
  /// In en, this message translates to:
  /// **'Adding payments'**
  String get addingPayments;

  /// No description provided for @autoAddClear.
  ///
  /// In en, this message translates to:
  /// **'Add clear payments automatically'**
  String get autoAddClear;

  /// No description provided for @autoAddClearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only purchases and refunds from a recognised bank, on a card you saved with its last 4 digits, with no doubt about the amount or a possible duplicate. Everything else waits for you.'**
  String get autoAddClearSubtitle;

  /// No description provided for @aiForUnclear.
  ///
  /// In en, this message translates to:
  /// **'AI for unclear messages'**
  String get aiForUnclear;

  /// No description provided for @aiOnProvider.
  ///
  /// In en, this message translates to:
  /// **'On · {provider}'**
  String aiOnProvider(String provider);

  /// No description provided for @aiOffProviders.
  ///
  /// In en, this message translates to:
  /// **'Off · DeepSeek, OpenRouter, Groq or Gemini'**
  String get aiOffProviders;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @keepMessageText.
  ///
  /// In en, this message translates to:
  /// **'Keep message text after review'**
  String get keepMessageText;

  /// No description provided for @dontKeep.
  ///
  /// In en, this message translates to:
  /// **'Don\'t keep'**
  String get dontKeep;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(int count);

  /// No description provided for @includeTextInBackups.
  ///
  /// In en, this message translates to:
  /// **'Include message text in backups'**
  String get includeTextInBackups;

  /// No description provided for @messageTextDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message text deleted'**
  String get messageTextDeleted;

  /// No description provided for @deleteAllMessageText.
  ///
  /// In en, this message translates to:
  /// **'Delete all message text now'**
  String get deleteAllMessageText;

  /// No description provided for @testMessage.
  ///
  /// In en, this message translates to:
  /// **'Test a message'**
  String get testMessage;

  /// No description provided for @pasteAlert.
  ///
  /// In en, this message translates to:
  /// **'Paste a bank or wallet alert'**
  String get pasteAlert;

  /// No description provided for @notAPayment.
  ///
  /// In en, this message translates to:
  /// **'Not a payment ({reason}).'**
  String notAPayment(String reason);

  /// No description provided for @percentSure.
  ///
  /// In en, this message translates to:
  /// **'{percent}% sure'**
  String percentSure(int percent);

  /// No description provided for @kindPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get kindPurchase;

  /// No description provided for @kindWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Cash withdrawal'**
  String get kindWithdrawal;

  /// No description provided for @kindMoneySent.
  ///
  /// In en, this message translates to:
  /// **'Money sent'**
  String get kindMoneySent;

  /// No description provided for @kindMoneyReceived.
  ///
  /// In en, this message translates to:
  /// **'Money received'**
  String get kindMoneyReceived;

  /// No description provided for @kindDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get kindDeposit;

  /// No description provided for @kindRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get kindRefund;

  /// No description provided for @kindBillPayment.
  ///
  /// In en, this message translates to:
  /// **'Bill payment'**
  String get kindBillPayment;

  /// No description provided for @kindCardPayment.
  ///
  /// In en, this message translates to:
  /// **'Card payment'**
  String get kindCardPayment;

  /// No description provided for @kindFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get kindFee;

  /// No description provided for @kindPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get kindPayment;

  /// No description provided for @addedPayments.
  ///
  /// In en, this message translates to:
  /// **'Added {count} payments'**
  String addedPayments(int count);

  /// No description provided for @addedWithProblems.
  ///
  /// In en, this message translates to:
  /// **'Added {count}; {problems} need a look: {first}'**
  String addedWithProblems(int count, int problems, String first);

  /// No description provided for @askingAi.
  ///
  /// In en, this message translates to:
  /// **'Asking the AI…'**
  String get askingAi;

  /// No description provided for @aiNothingToAdd.
  ///
  /// In en, this message translates to:
  /// **'The AI had nothing to add'**
  String get aiNothingToAdd;

  /// No description provided for @updatedPayments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 payment} other{Updated {count} payments}}'**
  String updatedPayments(int count);

  /// No description provided for @aiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI unavailable: {error}'**
  String aiUnavailable(String error);

  /// No description provided for @convertingTo.
  ///
  /// In en, this message translates to:
  /// **'Converting to {currency}…'**
  String convertingTo(String currency);

  /// No description provided for @noRateYetEdit.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate yet · tap Edit to enter the {currency} amount'**
  String noRateYetEdit(String currency);

  /// No description provided for @cardFeePercent.
  ///
  /// In en, this message translates to:
  /// **' + {percent}% card fee'**
  String cardFeePercent(String percent);

  /// No description provided for @rateEstimate.
  ///
  /// In en, this message translates to:
  /// **'exchange rate estimate'**
  String get rateEstimate;

  /// No description provided for @paymentsToReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments to review'**
  String get paymentsToReviewTitle;

  /// No description provided for @detectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Detection settings'**
  String get detectionSettings;

  /// No description provided for @nothingDetected.
  ///
  /// In en, this message translates to:
  /// **'Nothing detected yet'**
  String get nothingDetected;

  /// No description provided for @nothingDetectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on payment detection to collect bank and wallet alerts here, or paste an alert.'**
  String get nothingDetectedSubtitle;

  /// No description provided for @setUpDetection.
  ///
  /// In en, this message translates to:
  /// **'Set up detection'**
  String get setUpDetection;

  /// No description provided for @checkUnclear.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Check the unclear payment with AI} other{Check {count} unclear payments with AI}}'**
  String checkUnclear(int count);

  /// No description provided for @addReady.
  ///
  /// In en, this message translates to:
  /// **'Add {count} ready payments'**
  String addReady(int count);

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up.'**
  String get allCaughtUp;

  /// No description provided for @addedAutoThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Added automatically this week'**
  String get addedAutoThisWeek;

  /// No description provided for @duplicatesDismissed.
  ///
  /// In en, this message translates to:
  /// **'Duplicates and dismissed ({count})'**
  String duplicatesDismissed(int count);

  /// No description provided for @chooseAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get chooseAnAccount;

  /// No description provided for @newProposal.
  ///
  /// In en, this message translates to:
  /// **'✨ New: {name}'**
  String newProposal(String name);

  /// No description provided for @chargedAmountLine.
  ///
  /// In en, this message translates to:
  /// **' · charged {currency} {amount}'**
  String chargedAmountLine(String currency, String amount);

  /// No description provided for @maybeEnteredAlready.
  ///
  /// In en, this message translates to:
  /// **'You may have entered this already'**
  String get maybeEnteredAlready;

  /// No description provided for @sameEntry.
  ///
  /// In en, this message translates to:
  /// **'Same entry'**
  String get sameEntry;

  /// No description provided for @sameAsOtherAlert.
  ///
  /// In en, this message translates to:
  /// **'Same payment as another alert'**
  String get sameAsOtherAlert;

  /// No description provided for @unclearMessage.
  ///
  /// In en, this message translates to:
  /// **'Unclear message: check the details'**
  String get unclearMessage;

  /// No description provided for @askAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get askAi;

  /// No description provided for @checkedWithAi.
  ///
  /// In en, this message translates to:
  /// **'Checked with AI'**
  String get checkedWithAi;

  /// No description provided for @showMessage.
  ///
  /// In en, this message translates to:
  /// **'Show message'**
  String get showMessage;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @reviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Review again'**
  String get reviewAgain;

  /// No description provided for @bankBalanceDiffers.
  ///
  /// In en, this message translates to:
  /// **'The bank says your balance is {balance}; Flourish differs by {difference}.'**
  String bankBalanceDiffers(String balance, String difference);

  /// No description provided for @matchBank.
  ///
  /// In en, this message translates to:
  /// **'Match bank'**
  String get matchBank;

  /// No description provided for @matchedBankBalance.
  ///
  /// In en, this message translates to:
  /// **'Matched balance in bank message'**
  String get matchedBankBalance;

  /// No description provided for @reviewPayment.
  ///
  /// In en, this message translates to:
  /// **'Review payment'**
  String get reviewPayment;

  /// No description provided for @chargedToAccountPaid.
  ///
  /// In en, this message translates to:
  /// **'Charged to the account ({account}); paid {currency} {amount}'**
  String chargedToAccountPaid(String account, String currency, String amount);

  /// No description provided for @chargedInEmpty.
  ///
  /// In en, this message translates to:
  /// **'Charged in {account} (empty: exchange rate + card fee); paid {currency} {amount}'**
  String chargedInEmpty(String account, String currency, String amount);

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @wentToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Went to one of your accounts?'**
  String get wentToYourAccount;

  /// No description provided for @noSomeoneElse.
  ///
  /// In en, this message translates to:
  /// **'No, someone else'**
  String get noSomeoneElse;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @cameFromYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Came from one of your accounts?'**
  String get cameFromYourAccount;

  /// No description provided for @merchantOrPerson.
  ///
  /// In en, this message translates to:
  /// **'Merchant or person'**
  String get merchantOrPerson;

  /// No description provided for @paymentAdded.
  ///
  /// In en, this message translates to:
  /// **'Payment added'**
  String get paymentAdded;

  /// No description provided for @accountGone.
  ///
  /// In en, this message translates to:
  /// **'Account no longer exists'**
  String get accountGone;

  /// No description provided for @chooseDifferentCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Choose different currencies'**
  String get chooseDifferentCurrencies;

  /// No description provided for @chooseDifferentCategories.
  ///
  /// In en, this message translates to:
  /// **'Choose different categories of the same type'**
  String get chooseDifferentCategories;

  /// No description provided for @categoryCycle.
  ///
  /// In en, this message translates to:
  /// **'Category hierarchy cannot contain a cycle'**
  String get categoryCycle;

  /// No description provided for @typeRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type RESTORE to confirm'**
  String get typeRestoreConfirm;

  /// No description provided for @chooseImportFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a CSV, Excel (.xlsx), OFX/QFX, QIF or PDF statement'**
  String get chooseImportFile;

  /// No description provided for @fileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read'**
  String get fileUnreadable;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import: {error}'**
  String importError(String error);

  /// No description provided for @pdfPasswordProtected.
  ///
  /// In en, this message translates to:
  /// **'This PDF is password protected. Enter its password to import it.'**
  String get pdfPasswordProtected;

  /// No description provided for @pdfNoText.
  ///
  /// In en, this message translates to:
  /// **'This PDF has no text, it looks like a scan. Import needs a text PDF: download the statement from your bank\'s website or app, or export CSV, Excel or OFX instead.'**
  String get pdfNoText;

  /// No description provided for @pdfNoTable.
  ///
  /// In en, this message translates to:
  /// **'No transaction table found in this PDF. Set up AI in Settings to read unusual layouts, or export CSV, Excel or OFX from your bank.'**
  String get pdfNoTable;

  /// No description provided for @noTransactionsInFile.
  ///
  /// In en, this message translates to:
  /// **'No transactions found in this file'**
  String get noTransactionsInFile;

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty'**
  String get fileEmpty;

  /// No description provided for @invalidHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'Invalid header row'**
  String get invalidHeaderRow;

  /// No description provided for @mapRequiredColumns.
  ///
  /// In en, this message translates to:
  /// **'Map date, type, account, and amount'**
  String get mapRequiredColumns;

  /// No description provided for @columnNumber.
  ///
  /// In en, this message translates to:
  /// **'Column {n}'**
  String columnNumber(int n);

  /// No description provided for @manualOverride.
  ///
  /// In en, this message translates to:
  /// **'manual override'**
  String get manualOverride;

  /// No description provided for @transactionNumber.
  ///
  /// In en, this message translates to:
  /// **'Transaction {id}'**
  String transactionNumber(String id);

  /// No description provided for @manageNamed.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String manageNamed(String name);

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @include.
  ///
  /// In en, this message translates to:
  /// **'Include'**
  String get include;

  /// No description provided for @exclude.
  ///
  /// In en, this message translates to:
  /// **'Exclude'**
  String get exclude;

  /// No description provided for @pdfStatementAi.
  ///
  /// In en, this message translates to:
  /// **'PDF statement (AI)'**
  String get pdfStatementAi;

  /// No description provided for @readingPage.
  ///
  /// In en, this message translates to:
  /// **'Reading page {page} of {total}…'**
  String readingPage(int page, int total);

  /// No description provided for @readingPart.
  ///
  /// In en, this message translates to:
  /// **'Reading part {part} of {total}…'**
  String readingPart(int part, int total);

  /// No description provided for @pdfAiBody.
  ///
  /// In en, this message translates to:
  /// **'No table Flourish recognises was found. The text of {pages, plural, =1{1 page} other{{pages} pages}} ({requests, plural, =1{1 request} other{{requests} requests}}) goes to {provider}, with account and card numbers, IBANs, phones, emails and customer name lines removed. Amounts, dates and descriptions are sent. Rows whose amount is not on the page are left out, and you review everything before it is added.'**
  String pdfAiBody(int pages, int requests, String provider);

  /// No description provided for @aiMappingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI mapping unavailable: {error}'**
  String aiMappingUnavailable(String error);

  /// No description provided for @typedAmounts.
  ///
  /// In en, this message translates to:
  /// **'Positive amounts with a Type column'**
  String get typedAmounts;

  /// No description provided for @signedAmounts.
  ///
  /// In en, this message translates to:
  /// **'Signed bank amounts: negative = expense'**
  String get signedAmounts;

  /// No description provided for @decimalPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period (1,234.56)'**
  String get decimalPeriod;

  /// No description provided for @decimalComma.
  ///
  /// In en, this message translates to:
  /// **'Comma (1.234,56)'**
  String get decimalComma;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @institution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get institution;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @includeInWealth.
  ///
  /// In en, this message translates to:
  /// **'Include in wealth totals'**
  String get includeInWealth;

  /// No description provided for @owedPerStatement.
  ///
  /// In en, this message translates to:
  /// **'Amount owed per statement (optional)'**
  String get owedPerStatement;

  /// No description provided for @reconciledBalance.
  ///
  /// In en, this message translates to:
  /// **'Reconciled balance (optional)'**
  String get reconciledBalance;

  /// No description provided for @reconciliationReason.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation reason'**
  String get reconciliationReason;

  /// No description provided for @reconciliationHistory.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation history'**
  String get reconciliationHistory;

  /// No description provided for @resumeAutomaticRate.
  ///
  /// In en, this message translates to:
  /// **'Resume automatic rate'**
  String get resumeAutomaticRate;

  /// No description provided for @manualExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Manual exchange rate'**
  String get manualExchangeRate;

  /// No description provided for @oneSourceUnitEquals.
  ///
  /// In en, this message translates to:
  /// **'One source unit equals'**
  String get oneSourceUnitEquals;

  /// No description provided for @effectiveDate.
  ///
  /// In en, this message translates to:
  /// **'Effective date'**
  String get effectiveDate;

  /// No description provided for @addOverride.
  ///
  /// In en, this message translates to:
  /// **'Add override'**
  String get addOverride;

  /// No description provided for @transactionTemplates.
  ///
  /// In en, this message translates to:
  /// **'Transaction templates'**
  String get transactionTemplates;

  /// No description provided for @newTemplate.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get newTemplate;

  /// No description provided for @saveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save template'**
  String get saveTemplate;

  /// No description provided for @reviewTemplateTx.
  ///
  /// In en, this message translates to:
  /// **'Review template transaction'**
  String get reviewTemplateTx;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// No description provided for @amountInAccountCurrency.
  ///
  /// In en, this message translates to:
  /// **'Amount in account currency'**
  String get amountInAccountCurrency;

  /// No description provided for @recordTransaction.
  ///
  /// In en, this message translates to:
  /// **'Record transaction'**
  String get recordTransaction;

  /// No description provided for @assignSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Assign subcategory'**
  String get assignSubcategory;

  /// No description provided for @childCategory.
  ///
  /// In en, this message translates to:
  /// **'Child category'**
  String get childCategory;

  /// No description provided for @parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get parentCategory;

  /// No description provided for @noParent.
  ///
  /// In en, this message translates to:
  /// **'No parent'**
  String get noParent;

  /// No description provided for @receipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get receipts;

  /// No description provided for @attachReceipt.
  ///
  /// In en, this message translates to:
  /// **'Attach receipt'**
  String get attachReceipt;

  /// No description provided for @encryptedBackup.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup'**
  String get encryptedBackup;

  /// No description provided for @passwordMin10.
  ///
  /// In en, this message translates to:
  /// **'Password (10+ characters)'**
  String get passwordMin10;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @replaceFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Replace current finances from backup'**
  String get replaceFromBackup;

  /// No description provided for @backupPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassword;

  /// No description provided for @typeRestoreReplaceAll.
  ///
  /// In en, this message translates to:
  /// **'Type RESTORE to replace all current data'**
  String get typeRestoreReplaceAll;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @localBackupHistory.
  ///
  /// In en, this message translates to:
  /// **'Local backup history'**
  String get localBackupHistory;

  /// No description provided for @restoreLocalBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore this local backup'**
  String get restoreLocalBackup;

  /// No description provided for @typeRestoreReplace.
  ///
  /// In en, this message translates to:
  /// **'Type RESTORE to replace current data'**
  String get typeRestoreReplace;

  /// No description provided for @chooseWorksheet.
  ///
  /// In en, this message translates to:
  /// **'Choose worksheet'**
  String get chooseWorksheet;

  /// No description provided for @worksheet.
  ///
  /// In en, this message translates to:
  /// **'Worksheet'**
  String get worksheet;

  /// No description provided for @pdfStatement.
  ///
  /// In en, this message translates to:
  /// **'PDF statement'**
  String get pdfStatement;

  /// No description provided for @readStatementAi.
  ///
  /// In en, this message translates to:
  /// **'Read this statement with AI?'**
  String get readStatementAi;

  /// No description provided for @useAi.
  ///
  /// In en, this message translates to:
  /// **'Use AI'**
  String get useAi;

  /// No description provided for @aiNoTransactionsPdf.
  ///
  /// In en, this message translates to:
  /// **'The AI found no transactions in this PDF'**
  String get aiNoTransactionsPdf;

  /// No description provided for @pdfPassword.
  ///
  /// In en, this message translates to:
  /// **'PDF password'**
  String get pdfPassword;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @pdfPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Banks often use your ID or account number'**
  String get pdfPasswordHint;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @whichHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'Which row has the column names?'**
  String get whichHeaderRow;

  /// No description provided for @headerRowNumber.
  ///
  /// In en, this message translates to:
  /// **'Header row number'**
  String get headerRowNumber;

  /// No description provided for @mapColumnsAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Map the columns with AI?'**
  String get mapColumnsAiTitle;

  /// No description provided for @mapColumnsAiBody.
  ///
  /// In en, this message translates to:
  /// **'Sends the column names and 5 rows, with account numbers, phones and emails masked. You can change every choice afterwards.'**
  String get mapColumnsAiBody;

  /// No description provided for @mapMyself.
  ///
  /// In en, this message translates to:
  /// **'Map myself'**
  String get mapMyself;

  /// No description provided for @mapColumns.
  ///
  /// In en, this message translates to:
  /// **'Map columns'**
  String get mapColumns;

  /// No description provided for @mapColumnsAi.
  ///
  /// In en, this message translates to:
  /// **'Map columns (suggested by AI)'**
  String get mapColumnsAi;

  /// No description provided for @notMapped.
  ///
  /// In en, this message translates to:
  /// **'Not mapped'**
  String get notMapped;

  /// No description provided for @amountConvention.
  ///
  /// In en, this message translates to:
  /// **'Amount convention'**
  String get amountConvention;

  /// No description provided for @decimalSeparator.
  ///
  /// In en, this message translates to:
  /// **'Decimal separator'**
  String get decimalSeparator;

  /// No description provided for @dateFormatNonIso.
  ///
  /// In en, this message translates to:
  /// **'Date format for non-ISO dates'**
  String get dateFormatNonIso;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @spreadsheet.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet'**
  String get spreadsheet;

  /// No description provided for @amountEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get amountEnter;

  /// No description provided for @amountCheckFormat.
  ///
  /// In en, this message translates to:
  /// **'Check the number format'**
  String get amountCheckFormat;

  /// No description provided for @amountNumbersOnly.
  ///
  /// In en, this message translates to:
  /// **'Enter numbers only'**
  String get amountNumbersOnly;

  /// No description provided for @amountNoDecimals.
  ///
  /// In en, this message translates to:
  /// **'{currency} has no decimals'**
  String amountNoDecimals(String currency);

  /// No description provided for @amountMaxDecimals.
  ///
  /// In en, this message translates to:
  /// **'Use at most {digits} decimals for {currency}'**
  String amountMaxDecimals(int digits, String currency);

  /// No description provided for @amountAboveZero.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero'**
  String get amountAboveZero;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get methodDebitCard;

  /// No description provided for @methodCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get methodCreditCard;

  /// No description provided for @methodPrepaidCard.
  ///
  /// In en, this message translates to:
  /// **'Prepaid card'**
  String get methodPrepaidCard;

  /// No description provided for @methodMobileWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile wallet'**
  String get methodMobileWallet;

  /// No description provided for @methodInstaPay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get methodInstaPay;

  /// No description provided for @methodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get methodBankTransfer;

  /// No description provided for @methodBnpl.
  ///
  /// In en, this message translates to:
  /// **'Installments (BNPL)'**
  String get methodBnpl;

  /// No description provided for @methodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get methodCard;

  /// No description provided for @intlLimit.
  ///
  /// In en, this message translates to:
  /// **'International limit'**
  String get intlLimit;

  /// No description provided for @intlLimitIn.
  ///
  /// In en, this message translates to:
  /// **'International limit ({currency})'**
  String intlLimitIn(String currency);

  /// No description provided for @intlLimitOptional.
  ///
  /// In en, this message translates to:
  /// **'International limit (optional)'**
  String get intlLimitOptional;

  /// No description provided for @availableAbroad.
  ///
  /// In en, this message translates to:
  /// **'Available abroad'**
  String get availableAbroad;

  /// No description provided for @overIntlLimitBy.
  ///
  /// In en, this message translates to:
  /// **'Over the international limit by {amount}'**
  String overIntlLimitBy(String amount);

  /// No description provided for @overCardIntlLimit.
  ///
  /// In en, this message translates to:
  /// **'This goes over the card\'s international limit by {amount}.'**
  String overCardIntlLimit(String amount);

  /// No description provided for @bankSaidAvailable.
  ///
  /// In en, this message translates to:
  /// **'Bank message on {date}: {amount} available'**
  String bankSaidAvailable(String date, String amount);

  /// No description provided for @bankSaidIntlAvailable.
  ///
  /// In en, this message translates to:
  /// **'Bank message on {date}: {amount} available abroad'**
  String bankSaidIntlAvailable(String date, String amount);

  /// No description provided for @bankLimitDiffers.
  ///
  /// In en, this message translates to:
  /// **'The bank says {available} is available on this card; Flourish differs by {difference}.'**
  String bankLimitDiffers(String available, String difference);

  /// No description provided for @matchedBankLimit.
  ///
  /// In en, this message translates to:
  /// **'Matched available limit in bank message'**
  String get matchedBankLimit;

  /// No description provided for @catSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get catSalary;

  /// No description provided for @catFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get catFreelance;

  /// No description provided for @catInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get catInvestment;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food & Drinks'**
  String get catFood;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catBills.
  ///
  /// In en, this message translates to:
  /// **'Bills & Utilities'**
  String get catBills;

  /// No description provided for @catEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get catEntertainment;

  /// No description provided for @catHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get catHealth;

  /// No description provided for @catEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get catEducation;

  /// No description provided for @catHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get catHousing;

  /// No description provided for @catTransferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer Out'**
  String get catTransferOut;

  /// No description provided for @catTransferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer In'**
  String get catTransferIn;

  /// No description provided for @catInvestmentPurchases.
  ///
  /// In en, this message translates to:
  /// **'Investment purchases'**
  String get catInvestmentPurchases;

  /// No description provided for @catInvestmentSales.
  ///
  /// In en, this message translates to:
  /// **'Investment sales'**
  String get catInvestmentSales;

  /// No description provided for @catPrincipalPaid.
  ///
  /// In en, this message translates to:
  /// **'Principal paid'**
  String get catPrincipalPaid;

  /// No description provided for @catPrincipalReceived.
  ///
  /// In en, this message translates to:
  /// **'Principal received'**
  String get catPrincipalReceived;

  /// No description provided for @catBankFees.
  ///
  /// In en, this message translates to:
  /// **'Bank fees'**
  String get catBankFees;

  /// No description provided for @catInterestCharges.
  ///
  /// In en, this message translates to:
  /// **'Interest & charges'**
  String get catInterestCharges;

  /// No description provided for @catInterestEarned.
  ///
  /// In en, this message translates to:
  /// **'Interest earned'**
  String get catInterestEarned;

  /// No description provided for @catchUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Catch up on the last 7 days'**
  String get catchUpTitle;

  /// No description provided for @catchUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find payments from the past week that aren\'t in Flourish yet'**
  String get catchUpSubtitle;

  /// No description provided for @catchUpIntro.
  ///
  /// In en, this message translates to:
  /// **'iPhone apps can\'t read your Messages, so bring last week\'s payments in one of two ways. Flourish compares them with what you already have and only asks about the missing ones.'**
  String get catchUpIntro;

  /// No description provided for @catchUpPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste bank alerts'**
  String get catchUpPasteTitle;

  /// No description provided for @catchUpPasteBody.
  ///
  /// In en, this message translates to:
  /// **'In Messages, copy each alert from the last 7 days and paste them here, one after another.'**
  String get catchUpPasteBody;

  /// No description provided for @catchUpPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste alerts here'**
  String get catchUpPasteHint;

  /// No description provided for @catchUpCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get catchUpCheck;

  /// No description provided for @catchUpStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a statement'**
  String get catchUpStatementTitle;

  /// No description provided for @catchUpStatementBody.
  ///
  /// In en, this message translates to:
  /// **'Download a statement from your bank app (PDF, CSV, OFX or QIF). Only the last 7 days are compared.'**
  String get catchUpStatementBody;

  /// No description provided for @catchUpChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get catchUpChooseFile;

  /// No description provided for @catchUpMissingHeader.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing missing} =1{1 payment is not in Flourish} other{{count} payments are not in Flourish}}'**
  String catchUpMissingHeader(int count);

  /// No description provided for @catchUpAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up: every payment from the last 7 days is already in Flourish.'**
  String get catchUpAllCaughtUp;

  /// No description provided for @catchUpAlreadyHeader.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 already in Flourish} other{{count} already in Flourish}}'**
  String catchUpAlreadyHeader(int count);

  /// No description provided for @catchUpMarkRecorded.
  ///
  /// In en, this message translates to:
  /// **'Mark as already added'**
  String get catchUpMarkRecorded;

  /// No description provided for @catchUpOlder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 older than 7 days} other{{count} older than 7 days}}'**
  String catchUpOlder(int count);

  /// No description provided for @catchUpIgnored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 code, offer or notice} other{{count} codes, offers or notices}}'**
  String catchUpIgnored(int count);

  /// No description provided for @catchUpRepeated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 already received} other{{count} already received}}'**
  String catchUpRepeated(int count);

  /// No description provided for @catchUpAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get catchUpAdd;

  /// No description provided for @catchUpSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get catchUpSkip;

  /// No description provided for @catchUpAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get catchUpAdded;

  /// No description provided for @catchUpSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get catchUpSkipped;

  /// No description provided for @catchUpAddAll.
  ///
  /// In en, this message translates to:
  /// **'Add all ({count})'**
  String catchUpAddAll(int count);

  /// No description provided for @catchUpOlderLeftOut.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row older than 7 days left out} other{{count} rows older than 7 days left out}}'**
  String catchUpOlderLeftOut(int count);

  /// No description provided for @catchUpReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing payments'**
  String get catchUpReviewTitle;

  /// No description provided for @catchUpChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose the account first'**
  String get catchUpChooseAccount;

  /// No description provided for @catchUpAlreadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Already in Flourish'**
  String get catchUpAlreadyTitle;

  /// No description provided for @iosGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic detection on iPhone'**
  String get iosGuideTitle;

  /// No description provided for @iosGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up Shortcuts so new bank alerts reach Flourish by themselves'**
  String get iosGuideSubtitle;

  /// No description provided for @iosGuideIntro.
  ///
  /// In en, this message translates to:
  /// **'iPhone doesn\'t let apps read Messages or notifications. A Shortcuts automation hands each new alert to Flourish in the background. Set it up once; it takes about two minutes.'**
  String get iosGuideIntro;

  /// No description provided for @iosGuideMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Bank SMS (Messages)'**
  String get iosGuideMessagesTitle;

  /// No description provided for @iosGuideMsg1.
  ///
  /// In en, this message translates to:
  /// **'Open the Shortcuts app, tap Automation, then +.'**
  String get iosGuideMsg1;

  /// No description provided for @iosGuideMsg2.
  ///
  /// In en, this message translates to:
  /// **'Choose Message. Under Message Contains type EGP (you can also pick your bank under Sender).'**
  String get iosGuideMsg2;

  /// No description provided for @iosGuideMsg3.
  ///
  /// In en, this message translates to:
  /// **'Choose Run Immediately, then Next.'**
  String get iosGuideMsg3;

  /// No description provided for @iosGuideMsg4.
  ///
  /// In en, this message translates to:
  /// **'Tap New Blank Automation, then Add Action, and search for Flourish.'**
  String get iosGuideMsg4;

  /// No description provided for @iosGuideMsg5.
  ///
  /// In en, this message translates to:
  /// **'Pick Import Transaction Text. Set Transaction Text to Shortcut Input › Content and Sender to Shortcut Input › Sender.'**
  String get iosGuideMsg5;

  /// No description provided for @iosGuideMsg6.
  ///
  /// In en, this message translates to:
  /// **'Tap Done. Repeat for جنيه, ج.م and any other currency your bank writes (USD, دولار…).'**
  String get iosGuideMsg6;

  /// No description provided for @iosGuideWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Apple Pay (Wallet)'**
  String get iosGuideWalletTitle;

  /// No description provided for @iosGuideWallet1.
  ///
  /// In en, this message translates to:
  /// **'In Shortcuts › Automation tap +, choose Transaction and pick your cards.'**
  String get iosGuideWallet1;

  /// No description provided for @iosGuideWallet2.
  ///
  /// In en, this message translates to:
  /// **'Choose Run Immediately, then New Blank Automation.'**
  String get iosGuideWallet2;

  /// No description provided for @iosGuideWallet3.
  ///
  /// In en, this message translates to:
  /// **'Add Flourish › Log Card Payment and set Amount, Merchant and Card from Shortcut Input.'**
  String get iosGuideWallet3;

  /// No description provided for @iosGuideWallet4.
  ///
  /// In en, this message translates to:
  /// **'Tap Done. Each Apple Pay payment now appears in Payments to review.'**
  String get iosGuideWallet4;

  /// No description provided for @iosGuideCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Check it works'**
  String get iosGuideCheckTitle;

  /// No description provided for @iosGuideCheck.
  ///
  /// In en, this message translates to:
  /// **'Wait for the next bank alert, or send yourself a test like “Purchase of EGP 10.00 at Test”. Flourish shows a notification and the payment waits in Payments to review.'**
  String get iosGuideCheck;

  /// No description provided for @iosGuideOpenShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Open Shortcuts'**
  String get iosGuideOpenShortcuts;

  /// No description provided for @iosGuideCatchUpHint.
  ///
  /// In en, this message translates to:
  /// **'Missed some days? Catch up brings in the last 7 days.'**
  String get iosGuideCatchUpHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
