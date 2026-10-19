// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flourish';

  @override
  String get greetingNight => 'Good night';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get showAmounts => 'Show amounts';

  @override
  String get hideAmounts => 'Hide amounts';

  @override
  String get settings => 'Settings';

  @override
  String paymentsToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments to review',
      one: '1 payment to review',
    );
    return '$_temp0';
  }

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get seeAll => 'See all';

  @override
  String get thisMonth => 'This month';

  @override
  String get income => 'Income';

  @override
  String get spending => 'Spending';

  @override
  String get saved => 'Saved';

  @override
  String needHistoricalRates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions need historical exchange rates.',
      one: '1 transaction needs historical exchange rates.',
    );
    return '$_temp0';
  }

  @override
  String get holdings => 'Holdings';

  @override
  String get budgets => 'Budgets';

  @override
  String get goals => 'Goals';

  @override
  String get recurring => 'Recurring';

  @override
  String get importAction => 'Import';

  @override
  String get noActivityYet => 'No activity yet';

  @override
  String get noActivitySubtitle =>
      'Add your first transaction and it will show up here.';

  @override
  String get getStartedTitle => 'Let’s get you set up';

  @override
  String get getStartedSubtitle =>
      'Add an account and your first transaction to get started.';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get addAnAccount => 'Add an account';

  @override
  String get motivationTitle => 'Daily boost';

  @override
  String get motivationWinTitle => 'Nice work';

  @override
  String get motivationNextHint => 'Shows another encouraging line';

  @override
  String motivationSaved(String amount) {
    return 'You kept $amount this month. Keep it growing!';
  }

  @override
  String motivationGoalMilestone(int percent, String goal) {
    return '$percent% of “$goal” reached. You’re getting there!';
  }

  @override
  String motivationGoalDone(String goal) {
    return '“$goal” is fully funded. Well done!';
  }

  @override
  String get motivationQuote1 => 'Small steps today, more freedom tomorrow.';

  @override
  String get motivationQuote2 => 'Every amount you track is money you control.';

  @override
  String get motivationQuote3 => 'Saving a little beats saving nothing.';

  @override
  String get motivationQuote4 => 'Your future self will thank you.';

  @override
  String get motivationQuote5 =>
      'Consistency beats intensity. Log today’s spending.';

  @override
  String get motivationQuote6 => 'A budget tells your money where to go.';

  @override
  String get motivationQuote7 => 'Progress, not perfection.';

  @override
  String get navHome => 'Home';

  @override
  String get navLedger => 'Ledger';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navWealth => 'Wealth';

  @override
  String get add => 'Add';

  @override
  String pageNotFound(String page) {
    return 'The page \"$page\" does not exist.';
  }

  @override
  String get accountNotFound => 'Account not found';

  @override
  String get accountNotFoundSubtitle =>
      'That account link is invalid or no longer available.';

  @override
  String get expense => 'Expense';

  @override
  String get transfer => 'Transfer';

  @override
  String get scanOrImport => 'Scan or import';

  @override
  String get whatToAdd => 'WHAT DO YOU WANT TO ADD?';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String themeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'light': 'Light',
      'dark': 'Dark',
      'other': 'System',
    });
    return '$_temp0';
  }

  @override
  String get language => 'Language';

  @override
  String get languageDevice => 'Device language';

  @override
  String get hideAmountsSubtitle =>
      'Show balances as dots until you tap the eye';

  @override
  String get defaultCurrency => 'Default Currency';

  @override
  String get manage => 'Manage';

  @override
  String get budgetsSubtitle => 'Spending limits by category';

  @override
  String get savingsGoals => 'Savings Goals';

  @override
  String get savingsGoalsSubtitle => 'Targets and progress';

  @override
  String get recurringSubtitle => 'Bills, salaries and subscriptions';

  @override
  String get cardsWallets => 'Cards & wallets';

  @override
  String get cardsWalletsSubtitle =>
      'Debit and credit cards, wallets, InstaPay';

  @override
  String get categories => 'Categories';

  @override
  String get categoriesSubtitle =>
      'Add, edit, or delete transaction categories';

  @override
  String get paymentDetection => 'Payment detection';

  @override
  String get paymentDetectionSubtitle =>
      'Find payments in bank and wallet alerts';

  @override
  String get smartImport => 'Smart Import';

  @override
  String get smartImportSubtitle => 'Paste bank alerts to create transactions';

  @override
  String get monthlyAutoIncome => 'Monthly Auto Income';

  @override
  String get autoMonthlyIncome => 'Auto Monthly Income';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get monthlyIncomeAmount => 'Monthly Income Amount';

  @override
  String get dayOfMonth => 'Day of Month';

  @override
  String get incomeAccount => 'Income Account';

  @override
  String get selectAccount => 'Select account';

  @override
  String get incomeCategory => 'Income Category';

  @override
  String get selectCategory => 'Select category';

  @override
  String get data => 'Data';

  @override
  String get exportData => 'Export Data';

  @override
  String get exportDataSubtitle => 'Save your data as JSON';

  @override
  String get importData => 'Import Data';

  @override
  String get importDataSubtitle => 'Restore from a JSON backup';

  @override
  String get resetAllData => 'Reset All Data';

  @override
  String get resetAllDataSubtitle =>
      'Delete all accounts, transactions, and budgets';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get builtWith => 'Built with';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get invalidBackup => 'Invalid or empty backup file.';

  @override
  String get importBackup => 'Import Backup';

  @override
  String get importBackupWarning =>
      'This will erase all current data and replace it with the backup. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get backupRestored => 'Complete backup restored.';

  @override
  String importedRecords(int count) {
    return 'Imported $count records successfully.';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get resetAllDataWarning =>
      'This will delete all your accounts, transactions, budgets, and settings. This cannot be undone.';

  @override
  String get allDataReset => 'All data has been reset';

  @override
  String get reset => 'Reset';

  @override
  String get toolsMoney => 'Money';

  @override
  String get toolsImportExport => 'Import & export';

  @override
  String get toolsSecurity => 'Security & backup';

  @override
  String get exchangeRates => 'Exchange rates';

  @override
  String get exchangeRatesSubtitle => 'Sources, dates, and manual overrides';

  @override
  String get manageAccounts => 'Manage accounts';

  @override
  String get manageAccountsSubtitle =>
      'Edit, group, archive, and reconcile balances';

  @override
  String get savedTemplates => 'Saved transaction templates';

  @override
  String get savedTemplatesSubtitle => 'Reuse frequent entries';

  @override
  String get subcategories => 'Subcategories';

  @override
  String get subcategoriesSubtitle => 'Split categories into finer groups';

  @override
  String get receiptAttachments => 'Receipt attachments';

  @override
  String get receiptAttachmentsSubtitle => 'Photos and files linked to entries';

  @override
  String get reportingMonthStarts => 'Reporting month starts on';

  @override
  String dayNumber(int day) {
    return 'Day $day';
  }

  @override
  String get reportingMonth => 'Reporting month';

  @override
  String get startDayRange => 'Start day (1–28)';

  @override
  String get chooseDayRange => 'Choose a day from 1 to 28';

  @override
  String get importFromApps => 'Import from other apps';

  @override
  String get importFromAppsSubtitle =>
      'Money Manager, Wallet, Monefy, Spendee, YNAB, bank CSV, OFX, QIF, Excel or PDF statements · review before anything is added';

  @override
  String get exportCsv => 'Export transactions as CSV';

  @override
  String get exportCsvSubtitle => 'Opens in any spreadsheet app';

  @override
  String get paymentReminders => 'Payment reminders';

  @override
  String get paymentRemindersSubtitle =>
      'Local notifications for expected payments and maturities';

  @override
  String get paymentRemindersEnabled => 'Payment reminders enabled';

  @override
  String get deviceLock => 'Device authentication lock';

  @override
  String get deviceLockOn => 'Enabled · tap to disable';

  @override
  String get deviceLockOff => 'Disabled · tap to enable';

  @override
  String get setUpPasscodeFirst => 'Set up your device passcode first';

  @override
  String get changeAppLockReason => 'Change Flourish app lock';

  @override
  String get stockApiKey => 'Stock quote API key';

  @override
  String get stockApiKeySubtitle =>
      'Optional Alpha Vantage key · stored securely on this device';

  @override
  String get alphaVantageKey => 'Alpha Vantage API key';

  @override
  String get personalApiKey => 'Personal API key';

  @override
  String get exportBackup => 'Export encrypted backup';

  @override
  String get exportBackupSubtitle =>
      'Includes holdings, contracts, activity, settings, and receipts';

  @override
  String get restoreBackup => 'Restore encrypted backup';

  @override
  String get restoreBackupSubtitle => 'Replaces everything with a backup file';

  @override
  String get backupHistory => 'Automatic backup history';

  @override
  String get backupHistorySubtitle =>
      'Seven local daily backups · remain on this device';

  @override
  String get save => 'Save';

  @override
  String enterField(String field) {
    return 'Enter $field';
  }

  @override
  String get owedCaps => 'OWED';

  @override
  String get creditBalanceCaps => 'CREDIT BALANCE';

  @override
  String get nothingOwedCaps => 'NOTHING OWED';

  @override
  String get noPaymentAccounts => 'No bank, wallet or card accounts';

  @override
  String get addOneFromAccounts => 'Add one from Accounts first';

  @override
  String get searchTransactionsHint => 'Search transactions...';

  @override
  String get all => 'All';

  @override
  String get searchTransactions => 'Search transactions';

  @override
  String get searchSubtitle => 'Type to search by note or type';

  @override
  String get noResults => 'No results found';

  @override
  String get unlockReason => 'Unlock your Flourish finances';

  @override
  String get authCancelled => 'Authentication cancelled';

  @override
  String get unlockToContinue =>
      'Unlock with your device authentication to continue.';

  @override
  String get financesLocked => 'Your finances are locked.';

  @override
  String get unlock => 'Unlock';

  @override
  String get screenshotAiTitle => 'Read screenshots with AI?';

  @override
  String screenshotAiBody(String provider) {
    return 'Android\'s on-device text reader cannot read Arabic. With this on, a screenshot you choose to read with AI is sent as an image to $provider. An image cannot be masked: names, card or account numbers and balances visible in it are sent too.';
  }

  @override
  String get freeTiersKeep => 'Free tiers may keep what you send.';

  @override
  String get screenshotAiFooter =>
      'On-device reading stays the default; nothing is sent until you tap \"Read with AI\". You can turn this off in AI settings.';

  @override
  String get notNow => 'Not now';

  @override
  String get turnOn => 'Turn on';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get pick => 'Pick';

  @override
  String get futureDateTitle => 'Date is in the future';

  @override
  String futureDateBody(String date) {
    return 'This entry is dated $date but changes the account balance now. For a payment that has not happened yet, a recurring payment or reminder may fit better.';
  }

  @override
  String get changeDate => 'Change date';

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deleteTransactionTitle => 'Delete transaction?';

  @override
  String get deleteTransactionBody =>
      'This removes the transaction and rebalances the linked account automatically.';

  @override
  String get keep => 'Keep';

  @override
  String get transactionDeleted => 'Transaction deleted';

  @override
  String get undo => 'Undo';

  @override
  String get manageAccount => 'Manage account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get transactions => 'Transactions';

  @override
  String get errorLoadingTransactions => 'Error loading transactions';

  @override
  String get errorLoadingAccount => 'Error loading account';

  @override
  String get transaction => 'Transaction';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String deleteAccountBody(String name) {
    return 'Delete \"$name\"? Accounts with transactions must be archived instead, so their history stays in your reports.';
  }

  @override
  String get inThisMonth => 'In this month';

  @override
  String get outThisMonth => 'Out this month';

  @override
  String get noTransactions => 'No transactions';

  @override
  String get addTransactionToStart => 'Add a transaction to get started.';

  @override
  String get cardsWalletsHelp =>
      'Add the cards and wallets that pay from this account so spending shows what paid and detected payments find the right account.';

  @override
  String get defaultLower => 'default';

  @override
  String fxFee(String percent) {
    return 'FX fee $percent%';
  }

  @override
  String get cashNoCards => 'Cash accounts have no cards or wallets';

  @override
  String get addCardOrWallet => 'Add card or wallet';

  @override
  String editNamed(String name) {
    return 'Edit $name';
  }

  @override
  String get instrumentName => 'Name (e.g. CIB Visa)';

  @override
  String get type => 'Type';

  @override
  String get cardNetwork => 'Card network';

  @override
  String get noneNotCard => 'None / not a card';

  @override
  String get last4Digits => 'Last 4 digits (matches bank messages)';

  @override
  String get bankOrWallet => 'Bank or wallet';

  @override
  String get other => 'Other';

  @override
  String get walletHandle => 'Wallet number or InstaPay address';

  @override
  String get foreignFeeOptional => 'Foreign transaction fee, % (optional)';

  @override
  String get defaultForAccount => 'Default for this account';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get status => 'Status';

  @override
  String get inUse => 'In use';

  @override
  String get archived => 'Archived';

  @override
  String get manageCategories => 'Manage Categories';

  @override
  String get noCategories => 'No categories';

  @override
  String get errorLoadingCategories => 'Error loading categories';

  @override
  String get category => 'Category';

  @override
  String get systemCategoryLocked =>
      'Used for automatic entries; cannot be deleted';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String deleteCategoryWithTx(String name, int count, String target) {
    return '\"$name\" has $count transactions. They will move to \"$target\", and budgets for this category will be removed.';
  }

  @override
  String get otherIncome => 'Other income';

  @override
  String deleteCategoryEmpty(String name) {
    return 'Delete \"$name\"? Budgets for it will be removed.';
  }

  @override
  String get editCategory => 'Edit Category';

  @override
  String get addCategory => 'Add Category';

  @override
  String get categoryName => 'Category Name';

  @override
  String get icon => 'Icon';

  @override
  String get color => 'Color';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get enterName => 'Please enter a name';

  @override
  String get noAccountsYet => 'No accounts yet';

  @override
  String get addFirstAccount => 'Add your first account to start tracking.';

  @override
  String accountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ACCOUNTS',
      one: '1 ACCOUNT',
    );
    return '$_temp0';
  }

  @override
  String get errorLoadingAccounts => 'Error loading accounts';

  @override
  String get addAccount => 'Add Account';

  @override
  String get accountName => 'Account name';

  @override
  String get accountNameHint => 'e.g. Main Bank';

  @override
  String get amountOweNow => 'Amount you owe now';

  @override
  String get currentBalance => 'Current balance';

  @override
  String get debtPositiveHint =>
      'Enter debt as a positive number; 0 for a paid-off card';

  @override
  String get leaveEmptyZero => 'Leave empty for 0';

  @override
  String get accountType => 'Account Type';

  @override
  String get currency => 'Currency';

  @override
  String get cardTerms => 'Card terms';

  @override
  String get creditLimit => 'Credit limit';

  @override
  String get interestPerYear => 'Interest % / year';

  @override
  String get statementDay => 'Statement day';

  @override
  String get dueDay => 'Due day';

  @override
  String get cardFeesLater =>
      'Fees (foreign transactions, cash advance, late payment) can be added from the card page.';

  @override
  String get enterAccountName => 'Please enter an account name';

  @override
  String maxDecimals(int count) {
    return 'Use at most $count decimals';
  }

  @override
  String get transfers => 'Transfers';

  @override
  String get search => 'Search';

  @override
  String get listView => 'List view';

  @override
  String get calendarView => 'Calendar view';

  @override
  String get allAccounts => 'All accounts';

  @override
  String get allCategories => 'All categories';

  @override
  String showingDay(String day) {
    return 'Showing $day · show whole month';
  }

  @override
  String get couldNotLoadTransactions => 'Could not load transactions';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get noTransactionsPeriod => 'No transactions in this period.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get chooseDateRange => 'Choose date range';

  @override
  String get clearRange => 'Clear range';

  @override
  String get nextMonth => 'Next month';

  @override
  String get goal => 'Goal';

  @override
  String get noGoalsYet => 'No goals yet';

  @override
  String get noGoalsSubtitle =>
      'Set a savings goal to start tracking progress.';

  @override
  String get errorLoadingGoals => 'Error loading goals';

  @override
  String get goalReached => 'Goal reached';

  @override
  String percentSaved(String percent) {
    return '$percent% saved';
  }

  @override
  String ofTarget(String amount) {
    return 'of $amount';
  }

  @override
  String get pastDeadline => 'Past deadline';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get deleteGoal => 'Delete goal';

  @override
  String get deleteGoalTitle => 'Delete goal?';

  @override
  String deleteGoalBody(String name) {
    return '\"$name\" and its progress will be removed.';
  }

  @override
  String addToGoal(String name) {
    return 'Add to \"$name\"';
  }

  @override
  String get amount => 'Amount';

  @override
  String get contribute => 'Contribute';

  @override
  String get newSavingsGoal => 'New Savings Goal';

  @override
  String get goalName => 'Goal Name';

  @override
  String get goalNameHint => 'e.g. New Laptop';

  @override
  String get targetAmount => 'Target Amount';

  @override
  String get deadline => 'Deadline';

  @override
  String get linkedAccount => 'Linked Account';

  @override
  String get createGoal => 'Create Goal';

  @override
  String get addCashOrBankFirst => 'Add a cash or bank account first';

  @override
  String get apiKeyRemoved => 'API key removed';

  @override
  String get apiKeySaved => 'API key saved';

  @override
  String get saveApiKeyFirst => 'Save an API key first';

  @override
  String get noModelsForKey => 'No models available for this key';

  @override
  String get addAiConfigFirst => 'Add a base URL, model and API key first';

  @override
  String connectedTo(String model) {
    return 'Connected to $model';
  }

  @override
  String get connectedNoJson =>
      'Connected, but the model did not follow the JSON instruction. Try another model.';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get useAiWhenUnsure => 'Use AI when unsure';

  @override
  String get useAiWhenUnsureSubtitle =>
      'Flourish reads alerts on your phone first. Only messages it cannot read confidently are sent to the AI.';

  @override
  String get provider => 'Provider';

  @override
  String freeTier(String provider) {
    return '$provider · free tier';
  }

  @override
  String get baseUrl => 'Base URL';

  @override
  String get model => 'Model';

  @override
  String get chooseModel => 'Choose model';

  @override
  String get apiKey => 'API key';

  @override
  String get apiKeySavedHint => '•••••••• (saved)';

  @override
  String get pasteYourKey => 'Paste your key';

  @override
  String get saveKey => 'Save key';

  @override
  String get keyStorageNote =>
      'Stored in the device keychain. Leave empty and save to remove it.';

  @override
  String get testConnection => 'Test connection';

  @override
  String askBelowConfidence(int percent) {
    return 'Ask the AI below $percent% confidence';
  }

  @override
  String percentConfidence(int percent) {
    return '$percent% confidence';
  }

  @override
  String get higherSendsMore =>
      'Higher sends more messages to the AI (better accuracy, more requests).';

  @override
  String get aiSuggestCategories => 'Let AI suggest new categories';

  @override
  String get aiSuggestCategoriesSubtitle =>
      'New categories are shown with ✨ and only created when you save.';

  @override
  String get hidePersonalData => 'Hide personal data';

  @override
  String get hidePersonalDataFree =>
      'Always on for free providers, which may keep prompts.';

  @override
  String get hidePersonalDataSubtitle =>
      'Masks account and card numbers, phones and emails before sending.';

  @override
  String get readArabicScreenshots => 'Read Arabic screenshots with AI';

  @override
  String providerNoImages(String provider) {
    return '$provider cannot read images; choose a model that can, such as Gemini.';
  }

  @override
  String get sendsImageUnmasked =>
      'Sends the image itself, unmasked, when you tap \"Read with AI\" in Smart Import.';

  @override
  String aiUsageThisMonth(String requests, String tokens) {
    return 'This month: $requests requests · $tokens tokens';
  }

  @override
  String get aiConnection => 'Connection';

  @override
  String get aiBehaviour => 'Behaviour';

  @override
  String get aiUsage => 'Usage';

  @override
  String importedSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count transactions',
      one: 'Imported 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String skippedCount(int count) {
    return '$count skipped';
  }

  @override
  String get reconcileOpening => 'Reconcile opening balances if needed.';

  @override
  String get reviewImport => 'Review import';

  @override
  String importCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count transactions',
      one: 'Import 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String newCount(int count) {
    return '$count new';
  }

  @override
  String alreadyImportedCount(int count) {
    return '$count already imported';
  }

  @override
  String possibleDuplicatesCount(int count) {
    return '$count possible duplicates';
  }

  @override
  String unreadableCount(int count) {
    return '$count unreadable';
  }

  @override
  String get unverifiedLayout =>
      'This layout was built from documentation, not a real export. Check a few rows below before importing.';

  @override
  String andMore(int count) {
    return '…and $count more';
  }

  @override
  String accountInFile(String name, String rows) {
    return '“$name” in the file · $rows';
  }

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String createNewAccount(String currency) {
    return 'Create new account ($currency)';
  }

  @override
  String get categoriesNotInApp => 'Categories not in Flourish';

  @override
  String get chooseCategoryDest =>
      'Choose where each one goes. New categories keep the parent from the file.';

  @override
  String createNamed(String name) {
    return 'Create “$name”';
  }

  @override
  String get changePerAccount => 'Change per account';

  @override
  String get nothingSelected => 'Nothing selected';

  @override
  String get alreadyImported => 'Already imported';

  @override
  String get possibleDuplicate => 'Possible duplicate';

  @override
  String get cannotImport => 'Cannot import';

  @override
  String moreRowsFollow(int count) {
    return '$count more rows follow the same choices';
  }

  @override
  String get noTextTryAi =>
      'No readable text found. For Arabic, try \"Read with AI\".';

  @override
  String get noTextTypeInstead =>
      'No readable text found. Type or paste the alert instead.';

  @override
  String textRecognitionFailed(String error) {
    return 'Text recognition failed: $error';
  }

  @override
  String providerNoImagesSettings(String provider) {
    return '$provider cannot read images. Choose a model that can, such as Gemini, in AI settings.';
  }

  @override
  String get aiNoText => 'The AI found no readable text in this image.';

  @override
  String modelCannotReadImage(String error) {
    return 'This model could not read the image ($error). Choose a model that reads images in AI settings.';
  }

  @override
  String aiReadingFailed(String error) {
    return 'AI reading failed: $error';
  }

  @override
  String get aiUnavailableOnDevice =>
      'AI unavailable, showing on-device results';

  @override
  String get noNewPayments => 'No new payments found';

  @override
  String paymentsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments ready to review',
      one: '1 payment ready to review',
    );
    return '$_temp0';
  }

  @override
  String skippedNotices(int count) {
    return '$count skipped (codes, offers, notices or already added)';
  }

  @override
  String couldNotAnalyse(String error) {
    return 'Could not analyse: $error';
  }

  @override
  String get reviewSharedScreenshot => 'Review shared payment screenshot';

  @override
  String get pasteAlertsTitle => 'Paste bank, wallet or Apple Pay alerts';

  @override
  String get pasteAlertsBody =>
      'Paste one alert or many at once. Each one is read on your phone and added to Payments to review.';

  @override
  String get keepAsReceipt => 'Keep this image as a receipt';

  @override
  String get readWithAiArabic => 'Read with AI (Arabic)';

  @override
  String get alertText => 'Alert text';

  @override
  String alertTextFrom(String source) {
    return 'Alert text (from $source)';
  }

  @override
  String get alertExample =>
      'Example: Apple Pay: Card 1234 spent 24.90 USD at Starbucks';

  @override
  String get paste => 'Paste';

  @override
  String get photo => 'Photo';

  @override
  String get analyze => 'Analyze';

  @override
  String get aiSecondReading => 'Unclear alerts get a second reading from AI.';

  @override
  String get readOnPhone =>
      'Read on your phone. Add an AI provider for tricky alerts.';

  @override
  String get aiSettings => 'AI settings';

  @override
  String get setUp => 'Set up';

  @override
  String get obligations => 'Obligations';

  @override
  String get reports => 'Reports';

  @override
  String get tools => 'Tools';

  @override
  String get pricesRefreshed => 'Prices refreshed';

  @override
  String get refreshPrices => 'Refresh prices';

  @override
  String get couldNotLoadNetWorth => 'Could not load net worth.';

  @override
  String get netWorthCaps => 'NET WORTH';

  @override
  String get knownNetWorthCaps => 'KNOWN NET WORTH';

  @override
  String get trendLineLater =>
      'Your trend line appears after a few days of tracking.';

  @override
  String get assets => 'Assets';

  @override
  String get debts => 'Debts';

  @override
  String get liquid => 'Liquid';

  @override
  String get pricesMissing =>
      'Some prices or exchange rates are missing. Totals include known values only.';

  @override
  String get pricesStale =>
      'Some prices are more than 72 hours old. Pull down to refresh.';

  @override
  String get reportingCurrency => 'Reporting currency';

  @override
  String get pageNotFoundTitle => 'Page not found';

  @override
  String get notFound => 'Not Found';

  @override
  String get destinationUnavailable =>
      'This destination is unavailable or may have moved.';

  @override
  String get backHome => 'Back Home';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get newTransaction => 'New Transaction';

  @override
  String get noAccountsAddFirst =>
      'No accounts available. Please add an account first.';

  @override
  String get needTwoAccounts => 'Add at least 2 accounts to transfer.';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String amountReceivedIn(String currency) {
    return 'Amount received in $currency';
  }

  @override
  String get whatArrived => 'What actually arrived after conversion';

  @override
  String transferFeeIn(String currency) {
    return 'Transfer fee in $currency (optional)';
  }

  @override
  String get account => 'Account';

  @override
  String get refundFor => 'Refund for';

  @override
  String get merchantOptional => 'Merchant or payee (optional)';

  @override
  String get addNote => 'Add a note';

  @override
  String get addRefund => 'Add Refund';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get addIncome => 'Add Income';

  @override
  String get paidWith => 'Paid with';

  @override
  String overCardLimit(String amount) {
    return 'This goes over the card limit by $amount.';
  }

  @override
  String get isRefund => 'This is a refund';

  @override
  String get isRefundSubtitle => 'Money back that reduces spending';

  @override
  String get paidOtherCurrency => 'Paid in another currency';

  @override
  String paidOtherCurrencySubtitle(String currency) {
    return 'e.g. USD online or abroad, charged in $currency';
  }

  @override
  String priceIn(String currency) {
    return 'Price in $currency';
  }

  @override
  String get feeIncluded => 'Charged amount already includes the bank fee';

  @override
  String chargedAmountNote(String account) {
    return 'The amount above is what $account was charged. Set a foreign transaction fee on the card to track it.';
  }

  @override
  String fxFeeInside(String percent, String fee, String charged) {
    return 'Foreign transaction fee $percent%: $fee inside $charged. Use the amount on your statement when you have it.';
  }

  @override
  String fxFeeOnTop(String percent, String fee, String charged) {
    return 'Foreign transaction fee $percent%: $fee on top of $charged. Use the amount on your statement when you have it.';
  }

  @override
  String get selectAccountError => 'Please select an account';

  @override
  String get selectDestinationError => 'Please select destination account';

  @override
  String get sameAccountsError =>
      'Transfer source and destination must be different';

  @override
  String get selectCategoryError => 'Please select a category';

  @override
  String get chooseCurrency => 'Choose a currency';

  @override
  String get transferEditNote =>
      'Changes apply to both linked accounts and the transfer fee.';

  @override
  String get editTransfer => 'Edit transfer';

  @override
  String get deleteTransfer => 'Delete transfer';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get refundReduces => 'Refund · reduces spending in its category';

  @override
  String get editLinkedTransfer => 'Edit linked transfer';

  @override
  String get fromAccount => 'From account';

  @override
  String get toAccount => 'To account';

  @override
  String get sourceAmount => 'Source amount';

  @override
  String get destinationAmount => 'Destination amount';

  @override
  String get sourceCurrencyFee => 'Source-currency fee';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note';

  @override
  String get deleteTransactionTitle2 => 'Delete Transaction';

  @override
  String get deleteTransactionConfirm =>
      'Are you sure? The account balance will be adjusted.';

  @override
  String paidOriginal(String currency, String amount) {
    return 'Paid $currency $amount.';
  }

  @override
  String paidOriginalWithFee(String currency, String amount, String percent) {
    return 'Paid $currency $amount; the $percent% foreign transaction fee follows this amount.';
  }

  @override
  String noRateForDate(String from, String to) {
    return 'No $from→$to rate for this date. Enter the amount in $to.';
  }

  @override
  String convertedAtRate(String from, String amount, String to) {
    return 'Converted $from $amount to $to at the rate for this date. Check it matches what was charged.';
  }

  @override
  String get recurringPayment => 'Recurring payment';

  @override
  String get recurringTransactions => 'Recurring Transactions';

  @override
  String get noRecurring => 'No recurring transactions';

  @override
  String get setUpAutomatic => 'Set up automatic transactions';

  @override
  String get errorLoading => 'Error loading';

  @override
  String get pausedCaps => 'PAUSED';

  @override
  String frequencyNext(String frequency, String date) {
    return '$frequency · next $date';
  }

  @override
  String notPosted(String reason) {
    return 'Not posted: $reason';
  }

  @override
  String get recurringOptions => 'Recurring options';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get newRecurring => 'New Recurring Transaction';

  @override
  String get editRecurring => 'Edit Recurring Transaction';

  @override
  String get toAccountHint => 'To account (e.g. your credit card or savings)';

  @override
  String get chargedTo => 'Charged to';

  @override
  String get notSet => 'Not set';

  @override
  String get frequency => 'Frequency';

  @override
  String get firstOccurrence => 'First Occurrence';

  @override
  String get nextOccurrence => 'Next Occurrence';

  @override
  String get endsOptional => 'Ends (optional)';

  @override
  String get noEndDate => 'No end date';

  @override
  String get never => 'Never';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get createRecurring => 'Create Recurring';

  @override
  String get chooseTransferTarget => 'Choose the account to transfer to';

  @override
  String get selectAccountCategory => 'Please select account and category';

  @override
  String get startInPast => 'Start date is in the past';

  @override
  String get tooManyMissed =>
      'More than 24 payments fall before today. The schedule will start from its next date; add older payments manually if you need them.';

  @override
  String missedPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count payments fall before today. Post them now, or start from the next date?',
      one:
          '1 payment falls before today. Post it now, or start from the next date?',
    );
    return '$_temp0';
  }

  @override
  String get startFromNext => 'Start from next date';

  @override
  String postCount(int count) {
    return 'Post $count';
  }

  @override
  String get noBudgets => 'No budgets set';

  @override
  String get noBudgetsSubtitle =>
      'Create a budget to track your spending limits.';

  @override
  String get createABudget => 'Create a budget';

  @override
  String activeBudgets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ACTIVE BUDGETS',
      one: '1 ACTIVE BUDGET',
    );
    return '$_temp0';
  }

  @override
  String get errorLoadingBudgets => 'Error loading budgets';

  @override
  String get deleteBudget => 'Delete Budget';

  @override
  String get deleteBudgetConfirm =>
      'Are you sure you want to delete this budget?';

  @override
  String budgetUsedPercent(String percent) {
    return '$percent% of budget used';
  }

  @override
  String get budgetOptions => 'Budget options';

  @override
  String budgetConfirmCurrency(String amount) {
    return 'Budget $amount · confirm its original currency using Edit.';
  }

  @override
  String overBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String remainingUsed(String amount, String percent) {
    return '$amount remaining · $percent% used';
  }

  @override
  String recordsNeedRates(int count) {
    return '$count records need exchange rates; spending is incomplete.';
  }

  @override
  String get previousBudgetPeriod => 'Previous budget period';

  @override
  String get nextBudgetPeriod => 'Next budget period';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get originalBudgetCurrency => 'Original budget currency';

  @override
  String get budgetAmount => 'Budget amount';

  @override
  String get startDate => 'Start date';

  @override
  String get period => 'Period';

  @override
  String get createBudget => 'Create Budget';

  @override
  String get budgetAmountTitle => 'Budget Amount';

  @override
  String budgetExists(String period) {
    return 'This category already has a $period budget. Edit it instead.';
  }

  @override
  String cardPaymentNote(String name) {
    return 'Card payment: $name';
  }

  @override
  String get cardInterest => 'Card interest';

  @override
  String get annualCardFee => 'Annual card fee';

  @override
  String get cardFee => 'Card fee';

  @override
  String get charge => 'Charge';

  @override
  String get interest => 'Interest';

  @override
  String get latePaymentFee => 'Late payment fee';

  @override
  String get annualFee => 'Annual fee';

  @override
  String get otherBankFee => 'Other bank fee';

  @override
  String get cardDetails => 'Card details';

  @override
  String get cardDetailsHelp =>
      'Add the limit, statement and due days and fees to see available credit, the minimum payment and interest.';

  @override
  String get setUpCardTerms => 'Set up card terms';

  @override
  String get credit => 'Credit';

  @override
  String get editCardTerms => 'Edit card terms';

  @override
  String get available => 'Available';

  @override
  String get limit => 'Limit';

  @override
  String limitUsed(String percent) {
    return '$percent% of the limit used';
  }

  @override
  String get under30Tip => 'keeping it under 30% helps your credit';

  @override
  String overLimitBy(String amount) {
    return 'Over the limit by $amount';
  }

  @override
  String get lastStatement => 'Last statement';

  @override
  String get stillToPay => 'Still to pay';

  @override
  String get minimumDue => 'Minimum due';

  @override
  String minimumDueBy(String date) {
    return 'Minimum due by $date';
  }

  @override
  String get interestIfUnpaid => 'Interest if unpaid (est.)';

  @override
  String get cashAdvances => 'Cash advances';

  @override
  String get payCard => 'Pay card';

  @override
  String get interestOrFee => 'Interest or fee';

  @override
  String termsOf(String name) {
    return '$name terms';
  }

  @override
  String creditLimitIn(String currency) {
    return 'Credit limit ($currency)';
  }

  @override
  String get purchaseInterest => 'Purchase interest, % a year';

  @override
  String get statementClosingDay => 'Statement closing day (1–31)';

  @override
  String get paymentDueDay => 'Payment due day (1–31)';

  @override
  String get minimumPaymentPercent => 'Minimum payment, % of statement';

  @override
  String minimumPaymentAtLeast(String currency) {
    return 'Minimum payment at least ($currency)';
  }

  @override
  String get foreignFeePercent => 'Foreign transaction fee, %';

  @override
  String get cashAdvanceFee => 'Cash advance fee, %';

  @override
  String cashAdvanceFeeMin(String currency) {
    return 'Cash advance fee at least ($currency)';
  }

  @override
  String get cashAdvanceInterest => 'Cash advance interest, % a year';

  @override
  String latePaymentFeeIn(String currency) {
    return 'Late payment fee ($currency)';
  }

  @override
  String addAccountToPayFrom(String currency) {
    return 'Add a $currency bank or cash account to pay from';
  }

  @override
  String payNamed(String name) {
    return 'Pay $name';
  }

  @override
  String get payFrom => 'Pay from';

  @override
  String amountMinimum(String amount) {
    return 'Amount (minimum $amount)';
  }

  @override
  String get pay => 'Pay';

  @override
  String chargeOn(String name) {
    return 'Charge on $name';
  }

  @override
  String amountIn(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get statementDate => 'Statement date';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get setPrice => 'Set price';

  @override
  String get useFeed => 'Use feed';

  @override
  String get linkMortgage => 'Link mortgage';

  @override
  String get adjust => 'Adjust';

  @override
  String get split => 'Split';

  @override
  String get activity => 'Activity';

  @override
  String get actualIncomeInAccount => 'Actual income in account currency';

  @override
  String pricePerUnitIn(String currency) {
    return 'Price per unit in $currency';
  }

  @override
  String get addHolding => 'Add holding';

  @override
  String get addHoldingHelp =>
      'Add gold, investments, property, crypto, or another asset. Existing holdings do not change your cash balance.';

  @override
  String get missingPrice => 'Missing price';

  @override
  String get needsPrice => 'Needs price';

  @override
  String costUnknown(String amount, String currency) {
    return 'Cost $amount $currency';
  }

  @override
  String get unknown => 'unknown';

  @override
  String get assetName => 'Asset name';

  @override
  String get assetClass => 'Asset class';

  @override
  String get quantityGrams => 'Quantity / weight in grams';

  @override
  String get acquisitionCurrency => 'Acquisition currency';

  @override
  String get totalCostShare => 'Total cost of your share (blank if unknown)';

  @override
  String get tickerSymbol => 'Ticker / crypto symbol';

  @override
  String get exchangeHint => 'Exchange (EGX, NASDAQ, etc.)';

  @override
  String get whereHeld => 'Where it is held';

  @override
  String get ownershipFraction => 'Ownership fraction (1 = 100%)';

  @override
  String get goldKarat => 'Gold karat';

  @override
  String get priceSource => 'Price source';

  @override
  String get datedManualPrices => 'Dated manual prices';

  @override
  String get freeMarketFeed => 'Free market feed when supported';

  @override
  String get currentResalePrice =>
      'Current unit / gram resale price (optional)';

  @override
  String get openingDate => 'Opening date';

  @override
  String get priceMustBePositive => 'Price must be positive';

  @override
  String valueNamed(String name) {
    return 'Value $name';
  }

  @override
  String get resalePricePerUnit => 'Resale price per unit / gram';

  @override
  String get quoteCurrency => 'Quote currency';

  @override
  String get quoteDate => 'Quote date';

  @override
  String get source => 'Source';

  @override
  String ownershipLine(String quantity, String unit, String percent) {
    return '$quantity $unit · ownership $percent%';
  }

  @override
  String get unrealizedGainCaps => 'UNREALIZED GAIN';

  @override
  String get gainUnknown => 'Unknown — cost or price unavailable';

  @override
  String get linkPropertyMortgage => 'Link property and mortgage';

  @override
  String get existingObligation =>
      'Existing obligation (counted once in net worth)';

  @override
  String get noLinkedMortgage => 'No linked mortgage';

  @override
  String get manualAppraisals => 'This asset uses dated manual appraisals.';

  @override
  String get adjustHoldingAudit => 'Adjust holding with an audit record';

  @override
  String get correctQuantity => 'Correct quantity';

  @override
  String get totalAcquisitionCost =>
      'Total acquisition cost (blank if unknown)';

  @override
  String get custodyLocation => 'Custody / location';

  @override
  String get adjustReason => 'Reason for adjustment';

  @override
  String get stockSplit => 'Stock split / quantity adjustment';

  @override
  String get newUnitsPerOld => 'New units per old unit';

  @override
  String get createCashAccountFirst => 'Create a cash account first';

  @override
  String get cashAccount => 'Cash account';

  @override
  String get incomeType => 'Income type';

  @override
  String get dividend => 'Dividend';

  @override
  String get rent => 'Rent';

  @override
  String get quantity => 'Quantity';

  @override
  String get actualGrossCash =>
      'Actual gross cash in account currency (optional)';

  @override
  String get feeInAccount => 'Fee in account currency';

  @override
  String get transactionDate => 'Transaction date';

  @override
  String activityOf(String name) {
    return '$name activity';
  }

  @override
  String get unknownCost => 'Unknown cost';

  @override
  String gainLabel(String amount) {
    return 'Gain $amount';
  }

  @override
  String get close => 'Close';

  @override
  String get assetGold => 'Gold';

  @override
  String get assetStock => 'Stock';

  @override
  String get assetFund => 'Fund';

  @override
  String get assetCrypto => 'Crypto';

  @override
  String get assetProperty => 'Property';

  @override
  String get assetCustom => 'Other asset';

  @override
  String ratesMatures(String rate, String date) {
    return '$rate% · matures $date';
  }

  @override
  String get contractDeposit => 'Deposit';

  @override
  String get contractCertificate => 'Certificate';

  @override
  String get contractLoan => 'Loan';

  @override
  String get contractReceivable => 'Money owed to you';

  @override
  String get contractCreditCard => 'Credit card';

  @override
  String get addContractOrDebt => 'Add contract or debt';

  @override
  String get expectedPaymentsNote =>
      'Expected payments never change cash until you confirm receipt or payment.';

  @override
  String get owed => 'Owed';

  @override
  String get principal => 'Principal';

  @override
  String get addContractObligation => 'Add contract or obligation';

  @override
  String get name => 'Name';

  @override
  String get existingPrincipal => 'Existing outstanding / invested principal';

  @override
  String get annualInterestCoupon => 'Annual interest / coupon (%)';

  @override
  String get counterparty => 'Bank / person / lender';

  @override
  String get interestConvention => 'Interest convention';

  @override
  String get flatRate => 'Flat fixed annual rate / periodic coupons';

  @override
  String get reducingBalance => 'Reducing balance, equal installments';

  @override
  String get manualSchedule => 'Enter an agreed schedule manually';

  @override
  String get paymentsPerYear => 'Payments per year';

  @override
  String get quarterly => 'Quarterly';

  @override
  String get halfYearly => 'Half-yearly';

  @override
  String get maturityDate => 'Maturity / end date';

  @override
  String get payoutAccount => 'Cash / payout account';

  @override
  String get linkedCard => 'Linked credit card (cards only)';

  @override
  String get cardStatementDay => 'Card statement day';

  @override
  String get cardPaymentDay => 'Card payment day';

  @override
  String get movePrincipalNow => 'Move principal from/to cash now?';

  @override
  String get existingPosition => 'No — this is an existing position';

  @override
  String get recordNewFunding => 'Yes — record new funding';

  @override
  String get cardDaysRange => 'Card days must be 1–31';

  @override
  String principalAnnual(String amount, String currency, String rate) {
    return '$amount $currency · $rate% annual';
  }

  @override
  String get equalInstallmentsNote =>
      'Equal installments; periodic rate = annual rate / payments per year.';

  @override
  String get flatCouponsNote =>
      'Flat coupons; final partial period is prorated by actual days in the scheduled period.';

  @override
  String outstandingAmount(String amount, String currency) {
    return 'Outstanding $amount $currency';
  }

  @override
  String billedLine(String billed, String unbilled, String older, String due) {
    return 'Billed $billed · unbilled $unbilled\nOlder / opening $older · due $due';
  }

  @override
  String get addAgreedPayment => 'Add agreed payment';

  @override
  String get earlySettlement => 'Early settlement';

  @override
  String get outstandingPrincipal => 'Outstanding principal';

  @override
  String get agreedFinalInterest => 'Agreed final interest / fee';

  @override
  String get noLinkedCashAccount => 'No linked cash account';

  @override
  String get recordEarlySettlement => 'Record early settlement';

  @override
  String principalInterestLine(String principal, String interest) {
    return 'Principal $principal · interest $interest';
  }

  @override
  String get confirmed => 'Confirmed';

  @override
  String get reverseConfirmedPayment => 'Reverse confirmed payment';

  @override
  String get reversePaymentTitle => 'Reverse payment?';

  @override
  String get reversePaymentBody =>
      'This reverses the linked cash entries and marks the payment unpaid.';

  @override
  String get reverse => 'Reverse';

  @override
  String confirmActual(String amount, String currency) {
    return 'Confirm actual $amount $currency';
  }

  @override
  String get cashAccountRecordNow => 'Cash account · record actual payment now';

  @override
  String get confirm => 'Confirm';

  @override
  String get payCreditCard => 'Pay credit card';

  @override
  String get dueDate => 'Due date';

  @override
  String get principalAmount => 'Principal amount';

  @override
  String get interestAmount => 'Interest amount';

  @override
  String get enterPositivePayment => 'Enter a positive payment';

  @override
  String get notRecorded => 'Not recorded';

  @override
  String get feesForeign => 'Foreign transaction fees';

  @override
  String get feesTransfer => 'Transfer fees';

  @override
  String get feesCashAdvance => 'Cash advance fees';

  @override
  String get feesLate => 'Late payment fees';

  @override
  String get feesAnnual => 'Annual card fees';

  @override
  String get feesInvestment => 'Investment fees';

  @override
  String get feesOther => 'Other bank fees';

  @override
  String percentVsLast(String percent) {
    return '$percent% vs last';
  }

  @override
  String priceFxGain(String price, String fx) {
    return 'Price $price · FX $fx';
  }

  @override
  String get expenses => 'Expenses';

  @override
  String get spendingByCategory => 'Spending by category';

  @override
  String get noSpendingMonth => 'No spending this month.';

  @override
  String get totalCaps => 'TOTAL';

  @override
  String get howYouPaid => 'How you paid';

  @override
  String get byCardOrWallet => 'By card or wallet';

  @override
  String get spendingByCurrency => 'Spending by currency';

  @override
  String get convertedAtEachDate =>
      'Converted to your reporting currency at each date.';

  @override
  String get feesInterestPaid => 'Fees and interest paid';

  @override
  String get incomeSources => 'Income sources';

  @override
  String get noIncomeMonth => 'No income this month.';

  @override
  String get assetAllocation => 'Asset allocation';

  @override
  String get noValuedAssets => 'No valued assets yet.';

  @override
  String get currencyExposure => 'Currency exposure';

  @override
  String get originalAmounts => 'Original amounts, before conversion.';

  @override
  String get holdingGains => 'Holding gains since opening';

  @override
  String get holdingGainsNote =>
      'Price gains and the FX effect on acquisition cost are separate. Missing acquisition history stays unknown.';

  @override
  String get noGainsYet => 'No gains recorded yet.';

  @override
  String get netWorthHistory => 'Net worth history';

  @override
  String get netWorthHistoryNote =>
      'Recorded observations only. No values are invented before tracking began.';

  @override
  String get chartAppearsLater =>
      'The chart appears after a few days of tracking.';

  @override
  String get expectedCashFlow => 'Expected cash flow · next 30 days';

  @override
  String get expectedCashFlowNote =>
      'Based on unconfirmed contract schedules. This is a projection, not available cash.';

  @override
  String get realizedGains => 'Realized investment gains';

  @override
  String get noRealizedGains => 'No realized gains yet.';

  @override
  String get bankWalletApps => 'Bank and wallet apps';

  @override
  String get searchApps => 'Search apps';

  @override
  String get noAppsFound => 'No apps found.';

  @override
  String get noMatchingApps => 'No matching apps.';

  @override
  String get readAlertsTitle => 'Read payment alerts?';

  @override
  String get readAlertsBody =>
      'Flourish will read notifications from your messaging app and the bank or wallet apps you choose, to find payment alerts (amount, merchant, card ending). Other notifications are ignored on the spot. One-time codes and declined payments are never saved, card numbers are reduced to their last 4 digits, and nothing leaves your phone. You review every payment before it is added, unless you turn on automatic adding.';

  @override
  String get continueAction => 'Continue';

  @override
  String get detectFromNotifications => 'Detect payments from notifications';

  @override
  String get detectFromNotificationsSubtitle =>
      'Bank SMS and bank or wallet app alerts go to your inbox';

  @override
  String get accessGranted => 'Notification access granted';

  @override
  String get accessNeeded => 'Notification access needed';

  @override
  String get restrictedSettingsHint =>
      'If the switch is greyed out, open App info › ⋮ › Allow restricted settings first.';

  @override
  String get grant => 'Grant';

  @override
  String get messagingAlwaysRead =>
      'Messaging apps are always read. Apps that posted money-like notifications appear here; tick the ones from your bank or wallet, or choose them from your installed apps.';

  @override
  String get noneSeenYet => 'None seen yet. They appear after the next alert.';

  @override
  String alertsCount(int count) {
    return '$count alerts';
  }

  @override
  String get chosenFromInstalled => 'Chosen from installed apps';

  @override
  String get chooseFromInstalled => 'Choose from installed apps';

  @override
  String get notifyNewPayments => 'Notify me about new payments';

  @override
  String get iosShortcutsIntro =>
      'iOS does not let apps read messages, so Shortcuts sends them to Flourish. Set this up once (iOS 17 or later):';

  @override
  String get iosStep1 =>
      'Open Shortcuts › Automation › New Automation › Message.';

  @override
  String get iosStep2 =>
      'Message Contains: EGP. Add a separate Message automation for LE. Choose Run Immediately. Make one more automation for each word your bank uses: جنيه, ج.م, and the currencies you pay in abroad or online, such as USD, دولار, EUR, SAR.';

  @override
  String get iosStep3 =>
      'Add the action \"Import Transaction Text\" from Flourish and pass it the Message and Sender.';

  @override
  String get iosStep4 =>
      'For Apple Pay: New Automation › Wallet › choose your cards › Run Immediately › \"Log Card Payment\" with Amount, Merchant and Card.';

  @override
  String get paymentsArriveInbox =>
      'Payments arrive in your inbox without opening Flourish.';

  @override
  String get addingPayments => 'Adding payments';

  @override
  String get autoAddClear => 'Add clear payments automatically';

  @override
  String get autoAddClearSubtitle =>
      'Only purchases and refunds from a recognised bank, on a card you saved with its last 4 digits, with no doubt about the amount or a possible duplicate. Everything else waits for you.';

  @override
  String get aiForUnclear => 'AI for unclear messages';

  @override
  String aiOnProvider(String provider) {
    return 'On · $provider';
  }

  @override
  String get aiOffProviders => 'Off · DeepSeek, OpenRouter, Groq or Gemini';

  @override
  String get privacy => 'Privacy';

  @override
  String get keepMessageText => 'Keep message text after review';

  @override
  String get dontKeep => 'Don\'t keep';

  @override
  String daysCount(int count) {
    return '$count days';
  }

  @override
  String get includeTextInBackups => 'Include message text in backups';

  @override
  String get messageTextDeleted => 'Message text deleted';

  @override
  String get deleteAllMessageText => 'Delete all message text now';

  @override
  String get testMessage => 'Test a message';

  @override
  String get pasteAlert => 'Paste a bank or wallet alert';

  @override
  String notAPayment(String reason) {
    return 'Not a payment ($reason).';
  }

  @override
  String percentSure(int percent) {
    return '$percent% sure';
  }

  @override
  String get kindPurchase => 'Purchase';

  @override
  String get kindWithdrawal => 'Cash withdrawal';

  @override
  String get kindMoneySent => 'Money sent';

  @override
  String get kindMoneyReceived => 'Money received';

  @override
  String get kindDeposit => 'Deposit';

  @override
  String get kindRefund => 'Refund';

  @override
  String get kindBillPayment => 'Bill payment';

  @override
  String get kindCardPayment => 'Card payment';

  @override
  String get kindFee => 'Fee';

  @override
  String get kindPayment => 'Payment';

  @override
  String addedPayments(int count) {
    return 'Added $count payments';
  }

  @override
  String addedWithProblems(int count, int problems, String first) {
    return 'Added $count; $problems need a look: $first';
  }

  @override
  String get askingAi => 'Asking the AI…';

  @override
  String get aiNothingToAdd => 'The AI had nothing to add';

  @override
  String updatedPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count payments',
      one: 'Updated 1 payment',
    );
    return '$_temp0';
  }

  @override
  String aiUnavailable(String error) {
    return 'AI unavailable: $error';
  }

  @override
  String convertingTo(String currency) {
    return 'Converting to $currency…';
  }

  @override
  String noRateYetEdit(String currency) {
    return 'No exchange rate yet · tap Edit to enter the $currency amount';
  }

  @override
  String cardFeePercent(String percent) {
    return ' + $percent% card fee';
  }

  @override
  String get rateEstimate => 'exchange rate estimate';

  @override
  String get paymentsToReviewTitle => 'Payments to review';

  @override
  String get detectionSettings => 'Detection settings';

  @override
  String get nothingDetected => 'Nothing detected yet';

  @override
  String get nothingDetectedSubtitle =>
      'Turn on payment detection to collect bank and wallet alerts here, or paste an alert.';

  @override
  String get setUpDetection => 'Set up detection';

  @override
  String checkUnclear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Check $count unclear payments with AI',
      one: 'Check the unclear payment with AI',
    );
    return '$_temp0';
  }

  @override
  String addReady(int count) {
    return 'Add $count ready payments';
  }

  @override
  String get allCaughtUp => 'All caught up.';

  @override
  String get addedAutoThisWeek => 'Added automatically this week';

  @override
  String duplicatesDismissed(int count) {
    return 'Duplicates and dismissed ($count)';
  }

  @override
  String get chooseAnAccount => 'Choose an account';

  @override
  String newProposal(String name) {
    return '✨ New: $name';
  }

  @override
  String chargedAmountLine(String currency, String amount) {
    return ' · charged $currency $amount';
  }

  @override
  String get maybeEnteredAlready => 'You may have entered this already';

  @override
  String get sameEntry => 'Same entry';

  @override
  String get sameAsOtherAlert => 'Same payment as another alert';

  @override
  String get unclearMessage => 'Unclear message: check the details';

  @override
  String get askAi => 'Ask AI';

  @override
  String get checkedWithAi => 'Checked with AI';

  @override
  String get showMessage => 'Show message';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get reviewAgain => 'Review again';

  @override
  String bankBalanceDiffers(String balance, String difference) {
    return 'The bank says your balance is $balance; Flourish differs by $difference.';
  }

  @override
  String get matchBank => 'Match bank';

  @override
  String get matchedBankBalance => 'Matched balance in bank message';

  @override
  String get reviewPayment => 'Review payment';

  @override
  String chargedToAccountPaid(String account, String currency, String amount) {
    return 'Charged to the account ($account); paid $currency $amount';
  }

  @override
  String chargedInEmpty(String account, String currency, String amount) {
    return 'Charged in $account (empty: exchange rate + card fee); paid $currency $amount';
  }

  @override
  String get automatic => 'Automatic';

  @override
  String get wentToYourAccount => 'Went to one of your accounts?';

  @override
  String get noSomeoneElse => 'No, someone else';

  @override
  String get choose => 'Choose';

  @override
  String get cameFromYourAccount => 'Came from one of your accounts?';

  @override
  String get merchantOrPerson => 'Merchant or person';

  @override
  String get paymentAdded => 'Payment added';

  @override
  String get accountGone => 'Account no longer exists';

  @override
  String get chooseDifferentCurrencies => 'Choose different currencies';

  @override
  String get chooseDifferentCategories =>
      'Choose different categories of the same type';

  @override
  String get categoryCycle => 'Category hierarchy cannot contain a cycle';

  @override
  String get typeRestoreConfirm => 'Type RESTORE to confirm';

  @override
  String get chooseImportFile =>
      'Choose a CSV, Excel (.xlsx), OFX/QFX, QIF or PDF statement';

  @override
  String get fileUnreadable => 'This file could not be read';

  @override
  String importError(String error) {
    return 'Import: $error';
  }

  @override
  String get pdfPasswordProtected =>
      'This PDF is password protected. Enter its password to import it.';

  @override
  String get pdfNoText =>
      'This PDF has no text, it looks like a scan. Import needs a text PDF: download the statement from your bank\'s website or app, or export CSV, Excel or OFX instead.';

  @override
  String get pdfNoTable =>
      'No transaction table found in this PDF. Set up AI in Settings to read unusual layouts, or export CSV, Excel or OFX from your bank.';

  @override
  String get noTransactionsInFile => 'No transactions found in this file';

  @override
  String get fileEmpty => 'The file is empty';

  @override
  String get invalidHeaderRow => 'Invalid header row';

  @override
  String get mapRequiredColumns => 'Map date, type, account, and amount';

  @override
  String columnNumber(int n) {
    return 'Column $n';
  }

  @override
  String get manualOverride => 'manual override';

  @override
  String transactionNumber(String id) {
    return 'Transaction $id';
  }

  @override
  String manageNamed(String name) {
    return 'Manage $name';
  }

  @override
  String get active => 'Active';

  @override
  String get include => 'Include';

  @override
  String get exclude => 'Exclude';

  @override
  String get pdfStatementAi => 'PDF statement (AI)';

  @override
  String readingPage(int page, int total) {
    return 'Reading page $page of $total…';
  }

  @override
  String readingPart(int part, int total) {
    return 'Reading part $part of $total…';
  }

  @override
  String pdfAiBody(int pages, int requests, String provider) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pages',
      one: '1 page',
    );
    String _temp1 = intl.Intl.pluralLogic(
      requests,
      locale: localeName,
      other: '$requests requests',
      one: '1 request',
    );
    return 'No table Flourish recognises was found. The text of $_temp0 ($_temp1) goes to $provider, with account and card numbers, IBANs, phones, emails and customer name lines removed. Amounts, dates and descriptions are sent. Rows whose amount is not on the page are left out, and you review everything before it is added.';
  }

  @override
  String aiMappingUnavailable(String error) {
    return 'AI mapping unavailable: $error';
  }

  @override
  String get typedAmounts => 'Positive amounts with a Type column';

  @override
  String get signedAmounts => 'Signed bank amounts: negative = expense';

  @override
  String get decimalPeriod => 'Period (1,234.56)';

  @override
  String get decimalComma => 'Comma (1.234,56)';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get institution => 'Institution';

  @override
  String get group => 'Group';

  @override
  String get includeInWealth => 'Include in wealth totals';

  @override
  String get owedPerStatement => 'Amount owed per statement (optional)';

  @override
  String get reconciledBalance => 'Reconciled balance (optional)';

  @override
  String get reconciliationReason => 'Reconciliation reason';

  @override
  String get reconciliationHistory => 'Reconciliation history';

  @override
  String get resumeAutomaticRate => 'Resume automatic rate';

  @override
  String get manualExchangeRate => 'Manual exchange rate';

  @override
  String get oneSourceUnitEquals => 'One source unit equals';

  @override
  String get effectiveDate => 'Effective date';

  @override
  String get addOverride => 'Add override';

  @override
  String get transactionTemplates => 'Transaction templates';

  @override
  String get newTemplate => 'New template';

  @override
  String get saveTemplate => 'Save template';

  @override
  String get reviewTemplateTx => 'Review template transaction';

  @override
  String get templateName => 'Template name';

  @override
  String get amountInAccountCurrency => 'Amount in account currency';

  @override
  String get recordTransaction => 'Record transaction';

  @override
  String get assignSubcategory => 'Assign subcategory';

  @override
  String get childCategory => 'Child category';

  @override
  String get parentCategory => 'Parent category';

  @override
  String get noParent => 'No parent';

  @override
  String get receipts => 'Receipts';

  @override
  String get attachReceipt => 'Attach receipt';

  @override
  String get encryptedBackup => 'Encrypted backup';

  @override
  String get passwordMin10 => 'Password (10+ characters)';

  @override
  String get export => 'Export';

  @override
  String get replaceFromBackup => 'Replace current finances from backup';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get typeRestoreReplaceAll =>
      'Type RESTORE to replace all current data';

  @override
  String get restore => 'Restore';

  @override
  String get localBackupHistory => 'Local backup history';

  @override
  String get restoreLocalBackup => 'Restore this local backup';

  @override
  String get typeRestoreReplace => 'Type RESTORE to replace current data';

  @override
  String get chooseWorksheet => 'Choose worksheet';

  @override
  String get worksheet => 'Worksheet';

  @override
  String get pdfStatement => 'PDF statement';

  @override
  String get readStatementAi => 'Read this statement with AI?';

  @override
  String get useAi => 'Use AI';

  @override
  String get aiNoTransactionsPdf => 'The AI found no transactions in this PDF';

  @override
  String get pdfPassword => 'PDF password';

  @override
  String get password => 'Password';

  @override
  String get pdfPasswordHint => 'Banks often use your ID or account number';

  @override
  String get open => 'Open';

  @override
  String get whichHeaderRow => 'Which row has the column names?';

  @override
  String get headerRowNumber => 'Header row number';

  @override
  String get mapColumnsAiTitle => 'Map the columns with AI?';

  @override
  String get mapColumnsAiBody =>
      'Sends the column names and 5 rows, with account numbers, phones and emails masked. You can change every choice afterwards.';

  @override
  String get mapMyself => 'Map myself';

  @override
  String get mapColumns => 'Map columns';

  @override
  String get mapColumnsAi => 'Map columns (suggested by AI)';

  @override
  String get notMapped => 'Not mapped';

  @override
  String get amountConvention => 'Amount convention';

  @override
  String get decimalSeparator => 'Decimal separator';

  @override
  String get dateFormatNonIso => 'Date format for non-ISO dates';

  @override
  String get review => 'Review';

  @override
  String get spreadsheet => 'Spreadsheet';

  @override
  String get amountEnter => 'Enter an amount';

  @override
  String get amountCheckFormat => 'Check the number format';

  @override
  String get amountNumbersOnly => 'Enter numbers only';

  @override
  String amountNoDecimals(String currency) {
    return '$currency has no decimals';
  }

  @override
  String amountMaxDecimals(int digits, String currency) {
    return 'Use at most $digits decimals for $currency';
  }

  @override
  String get amountAboveZero => 'Enter an amount above zero';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodDebitCard => 'Debit card';

  @override
  String get methodCreditCard => 'Credit card';

  @override
  String get methodPrepaidCard => 'Prepaid card';

  @override
  String get methodMobileWallet => 'Mobile wallet';

  @override
  String get methodInstaPay => 'InstaPay';

  @override
  String get methodBankTransfer => 'Bank transfer';

  @override
  String get methodBnpl => 'Installments (BNPL)';

  @override
  String get methodCard => 'Card';

  @override
  String get intlLimit => 'International limit';

  @override
  String intlLimitIn(String currency) {
    return 'International limit ($currency)';
  }

  @override
  String get intlLimitOptional => 'International limit (optional)';

  @override
  String get availableAbroad => 'Available abroad';

  @override
  String overIntlLimitBy(String amount) {
    return 'Over the international limit by $amount';
  }

  @override
  String overCardIntlLimit(String amount) {
    return 'This goes over the card\'s international limit by $amount.';
  }

  @override
  String bankSaidAvailable(String date, String amount) {
    return 'Bank message on $date: $amount available';
  }

  @override
  String bankSaidIntlAvailable(String date, String amount) {
    return 'Bank message on $date: $amount available abroad';
  }

  @override
  String bankLimitDiffers(String available, String difference) {
    return 'The bank says $available is available on this card; Flourish differs by $difference.';
  }

  @override
  String get matchedBankLimit => 'Matched available limit in bank message';

  @override
  String get catSalary => 'Salary';

  @override
  String get catFreelance => 'Freelance';

  @override
  String get catInvestment => 'Investment';

  @override
  String get catFood => 'Food & Drinks';

  @override
  String get catTransport => 'Transport';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catBills => 'Bills & Utilities';

  @override
  String get catEntertainment => 'Entertainment';

  @override
  String get catHealth => 'Health';

  @override
  String get catEducation => 'Education';

  @override
  String get catHousing => 'Housing';

  @override
  String get catTransferOut => 'Transfer Out';

  @override
  String get catTransferIn => 'Transfer In';

  @override
  String get catInvestmentPurchases => 'Investment purchases';

  @override
  String get catInvestmentSales => 'Investment sales';

  @override
  String get catPrincipalPaid => 'Principal paid';

  @override
  String get catPrincipalReceived => 'Principal received';

  @override
  String get catBankFees => 'Bank fees';

  @override
  String get catInterestCharges => 'Interest & charges';

  @override
  String get catInterestEarned => 'Interest earned';

  @override
  String get catchUpTitle => 'Catch up on the last 7 days';

  @override
  String get catchUpSubtitle =>
      'Find payments from the past week that aren\'t in Flourish yet';

  @override
  String get catchUpIntro =>
      'iPhone apps can\'t read your Messages, so bring last week\'s payments in one of two ways. Flourish compares them with what you already have and only asks about the missing ones.';

  @override
  String get catchUpPasteTitle => 'Paste bank alerts';

  @override
  String get catchUpPasteBody =>
      'In Messages, copy each alert from the last 7 days and paste them here, one after another.';

  @override
  String get catchUpPasteHint => 'Paste alerts here';

  @override
  String get catchUpCheck => 'Check';

  @override
  String get catchUpStatementTitle => 'Import a statement';

  @override
  String get catchUpStatementBody =>
      'Download a statement from your bank app (PDF, CSV, OFX or QIF). Only the last 7 days are compared.';

  @override
  String get catchUpChooseFile => 'Choose file';

  @override
  String catchUpMissingHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments are not in Flourish',
      one: '1 payment is not in Flourish',
      zero: 'Nothing missing',
    );
    return '$_temp0';
  }

  @override
  String get catchUpAllCaughtUp =>
      'You\'re all caught up: every payment from the last 7 days is already in Flourish.';

  @override
  String catchUpAlreadyHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already in Flourish',
      one: '1 already in Flourish',
    );
    return '$_temp0';
  }

  @override
  String get catchUpMarkRecorded => 'Mark as already added';

  @override
  String catchUpOlder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count older than 7 days',
      one: '1 older than 7 days',
    );
    return '$_temp0';
  }

  @override
  String catchUpIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count codes, offers or notices',
      one: '1 code, offer or notice',
    );
    return '$_temp0';
  }

  @override
  String catchUpRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already received',
      one: '1 already received',
    );
    return '$_temp0';
  }

  @override
  String get catchUpAdd => 'Add';

  @override
  String get catchUpSkip => 'Skip';

  @override
  String get catchUpAdded => 'Added';

  @override
  String get catchUpSkipped => 'Skipped';

  @override
  String catchUpAddAll(int count) {
    return 'Add all ($count)';
  }

  @override
  String catchUpOlderLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows older than 7 days left out',
      one: '1 row older than 7 days left out',
    );
    return '$_temp0';
  }

  @override
  String get catchUpReviewTitle => 'Missing payments';

  @override
  String get catchUpChooseAccount => 'Choose the account first';

  @override
  String get catchUpAlreadyTitle => 'Already in Flourish';

  @override
  String get iosGuideTitle => 'Automatic detection on iPhone';

  @override
  String get iosGuideSubtitle =>
      'Set up Shortcuts so new bank alerts reach Flourish by themselves';

  @override
  String get iosGuideIntro =>
      'iPhone doesn\'t let apps read Messages or notifications. A Shortcuts automation hands each new alert to Flourish in the background. Set it up once; it takes about two minutes.';

  @override
  String get iosGuideMessagesTitle => '1. Bank SMS (Messages)';

  @override
  String get iosGuideMsg1 => 'Open the Shortcuts app, tap Automation, then +.';

  @override
  String get iosGuideMsg2 =>
      'Choose Message. Under Message Contains type EGP (you can also pick your bank under Sender). Add a separate Message automation with Message Contains: LE; existing automations must be updated manually.';

  @override
  String get iosGuideMsg3 => 'Choose Run Immediately, then Next.';

  @override
  String get iosGuideMsg4 =>
      'Tap New Blank Automation, then Add Action, and search for Flourish.';

  @override
  String get iosGuideMsg5 =>
      'Pick Import Transaction Text. Set Transaction Text to Shortcut Input › Content and Sender to Shortcut Input › Sender.';

  @override
  String get iosGuideMsg6 =>
      'Tap Done. Repeat for جنيه, ج.م and any other currency your bank writes (USD, دولار…).';

  @override
  String get iosGuideWalletTitle => '2. Apple Pay (Wallet)';

  @override
  String get iosGuideWallet1 =>
      'In Shortcuts › Automation tap +, choose Transaction and pick your cards.';

  @override
  String get iosGuideWallet2 =>
      'Choose Run Immediately, then New Blank Automation.';

  @override
  String get iosGuideWallet3 =>
      'Add Flourish › Log Card Payment and set Amount, Merchant and Card from Shortcut Input.';

  @override
  String get iosGuideWallet4 =>
      'Tap Done. Each Apple Pay payment now appears in Payments to review.';

  @override
  String get iosGuideCheckTitle => '3. Check it works';

  @override
  String get iosGuideCheck =>
      'Wait for the next bank alert, or send yourself a test like “Purchase of EGP 10.00 at Test”. Flourish shows a notification and the payment waits in Payments to review.';

  @override
  String get iosGuideOpenShortcuts => 'Open Shortcuts';

  @override
  String get iosGuideCatchUpHint =>
      'Missed some days? Catch up brings in the last 7 days.';

  @override
  String get useTemplate => 'Use template';

  @override
  String get noTemplates =>
      'No templates yet. Create one in Tools → Transaction templates.';

  @override
  String get chooseTemplateAmount => 'Choose an amount';

  @override
  String get templateCategoryMismatch =>
      'Choose a category matching the transaction type';

  @override
  String get templatePositiveAmounts => 'Enter 1–3 positive amounts';

  @override
  String get homeScreenWidgets => 'Home screen widgets';

  @override
  String get widgetSetup =>
      'On Android, long-press Home → Widgets → Flourish. On iPhone, long-press Home → Edit → Add Widget → Flourish. Add Monthly summary or Quick add. Amounts are hidden while app lock or Hide amounts is on. Totals show their last update; open Flourish to refresh.';

  @override
  String get widgetMonthlySummary => 'Monthly summary';

  @override
  String get widgetQuickAdd => 'Quick add';

  @override
  String get widgetOpenToRefresh => 'Open Flourish to refresh';

  @override
  String get widgetUpdated => 'Updated';

  @override
  String get toolsSubtitle => 'Templates, imports, backup, and security';

  @override
  String get globalSearch => 'Search everything';

  @override
  String get searchEverythingHint => 'Records, merchants, tools…';

  @override
  String get searchIndexing => 'Preparing search index…';

  @override
  String get searchFailed => 'Search failed. Try again.';

  @override
  String get searchFeatures => 'App features';

  @override
  String get searchObligations => 'Obligations';

  @override
  String get searchFilters => 'Transaction filters';

  @override
  String get minimumAmount => 'Minimum amount';

  @override
  String get maximumAmount => 'Maximum amount';

  @override
  String get searchRelevance => 'Most relevant';

  @override
  String get searchNewest => 'Newest first';

  @override
  String get loadMoreResults => 'More results';

  @override
  String get currencyConverter => 'Currency converter';

  @override
  String get referenceRate => 'Provider reference';

  @override
  String get effectiveRate => 'Your effective rate';

  @override
  String get rateUnavailable => 'No rate available for this pair.';

  @override
  String get cachedRateNotice => 'Cached daily reference. Pull to refresh.';

  @override
  String get rateRefreshFailed => 'Could not refresh. Cached rates retained.';

  @override
  String get rateStale => 'Last fetched over 24 hours ago';

  @override
  String get favoritePairs => 'Favorite pairs';

  @override
  String get searchCurrency => 'Search currencies';

  @override
  String get rateAsOf => 'Rate date';

  @override
  String get rateFetched => 'Last fetched';

  @override
  String get searchMissingRecord => 'This record no longer exists.';

  @override
  String get searchStart => 'Search records and app features';

  @override
  String get searchAmountCurrency =>
      'Amount filters use the selected currency without conversion.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get searchRetry => 'Retry';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchApply => 'Apply';
}
