// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Flourish';

  @override
  String get greetingNight => 'تصبح على خير';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingAfternoon => 'مساء الخير';

  @override
  String get greetingEvening => 'مساء الخير';

  @override
  String get showAmounts => 'إظهار المبالغ';

  @override
  String get hideAmounts => 'إخفاء المبالغ';

  @override
  String get settings => 'الإعدادات';

  @override
  String paymentsToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دفعة للمراجعة',
      few: '$count دفعات للمراجعة',
      two: 'دفعتان للمراجعة',
      one: 'دفعة واحدة للمراجعة',
    );
    return '$_temp0';
  }

  @override
  String get recentActivity => 'النشاط الأخير';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get income => 'الدخل';

  @override
  String get spending => 'الإنفاق';

  @override
  String get saved => 'المدّخر';

  @override
  String needHistoricalRates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معاملة تحتاج إلى أسعار صرف تاريخية.',
      few: '$count معاملات تحتاج إلى أسعار صرف تاريخية.',
      two: 'معاملتان تحتاجان إلى أسعار صرف تاريخية.',
      one: 'معاملة واحدة تحتاج إلى أسعار صرف تاريخية.',
    );
    return '$_temp0';
  }

  @override
  String get holdings => 'الأصول';

  @override
  String get budgets => 'الميزانيات';

  @override
  String get goals => 'الأهداف';

  @override
  String get recurring => 'المتكررة';

  @override
  String get importAction => 'استيراد';

  @override
  String get noActivityYet => 'لا يوجد نشاط بعد';

  @override
  String get noActivitySubtitle => 'أضف أول معاملة وستظهر هنا.';

  @override
  String get getStartedTitle => 'لنبدأ الإعداد';

  @override
  String get getStartedSubtitle => 'أضف حسابًا وأول معاملة للبدء.';

  @override
  String get addTransaction => 'إضافة معاملة';

  @override
  String get addAnAccount => 'إضافة حساب';

  @override
  String get motivationTitle => 'دفعة اليوم';

  @override
  String get motivationWinTitle => 'أحسنت';

  @override
  String get motivationNextHint => 'يعرض عبارة تشجيعية أخرى';

  @override
  String motivationSaved(String amount) {
    return 'وفّرت $amount هذا الشهر. واصل!';
  }

  @override
  String motivationGoalMilestone(int percent, String goal) {
    return 'وصلت إلى $percent٪ من «$goal». أنت تقترب!';
  }

  @override
  String motivationGoalDone(String goal) {
    return 'اكتمل تمويل «$goal». عمل رائع!';
  }

  @override
  String get motivationQuote1 => 'خطوات صغيرة اليوم، حرية أكبر غدًا.';

  @override
  String get motivationQuote2 => 'كل مبلغ تتابعه هو مال تتحكم فيه.';

  @override
  String get motivationQuote3 => 'ادّخار القليل أفضل من لا شيء.';

  @override
  String get motivationQuote4 => 'ستشكرك نفسك في المستقبل.';

  @override
  String get motivationQuote5 => 'الاستمرار أهم من الحماس. سجّل مصروفات اليوم.';

  @override
  String get motivationQuote6 => 'الميزانية تخبر مالك إلى أين يذهب.';

  @override
  String get motivationQuote7 => 'التقدّم، لا الكمال.';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navLedger => 'السجل';

  @override
  String get navAccounts => 'الحسابات';

  @override
  String get navWealth => 'الثروة';

  @override
  String get add => 'إضافة';

  @override
  String pageNotFound(String page) {
    return 'الصفحة \"$page\" غير موجودة.';
  }

  @override
  String get accountNotFound => 'الحساب غير موجود';

  @override
  String get accountNotFoundSubtitle =>
      'رابط الحساب غير صالح أو لم يعد متاحًا.';

  @override
  String get expense => 'مصروف';

  @override
  String get transfer => 'تحويل';

  @override
  String get scanOrImport => 'مسح أو استيراد';

  @override
  String get whatToAdd => 'ماذا تريد أن تضيف؟';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'السمة';

  @override
  String themeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'light': 'فاتح',
      'dark': 'داكن',
      'other': 'حسب النظام',
    });
    return '$_temp0';
  }

  @override
  String get language => 'اللغة';

  @override
  String get languageDevice => 'لغة الجهاز';

  @override
  String get hideAmountsSubtitle =>
      'عرض الأرصدة كنقاط حتى تضغط على أيقونة العين';

  @override
  String get defaultCurrency => 'العملة الافتراضية';

  @override
  String get manage => 'الإدارة';

  @override
  String get budgetsSubtitle => 'حدود الإنفاق حسب الفئة';

  @override
  String get savingsGoals => 'أهداف الادخار';

  @override
  String get savingsGoalsSubtitle => 'الأهداف والتقدّم';

  @override
  String get recurringSubtitle => 'الفواتير والرواتب والاشتراكات';

  @override
  String get cardsWallets => 'البطاقات والمحافظ';

  @override
  String get cardsWalletsSubtitle =>
      'بطاقات الخصم والائتمان والمحافظ وإنستاباي';

  @override
  String get categories => 'الفئات';

  @override
  String get categoriesSubtitle => 'إضافة فئات المعاملات أو تعديلها أو حذفها';

  @override
  String get paymentDetection => 'اكتشاف المدفوعات';

  @override
  String get paymentDetectionSubtitle =>
      'العثور على المدفوعات في تنبيهات البنوك والمحافظ';

  @override
  String get smartImport => 'الاستيراد الذكي';

  @override
  String get smartImportSubtitle => 'الصق تنبيهات البنك لإنشاء معاملات';

  @override
  String get monthlyAutoIncome => 'الدخل الشهري التلقائي';

  @override
  String get autoMonthlyIncome => 'دخل شهري تلقائي';

  @override
  String get enabled => 'مفعّل';

  @override
  String get disabled => 'متوقف';

  @override
  String get monthlyIncomeAmount => 'مبلغ الدخل الشهري';

  @override
  String get dayOfMonth => 'يوم الشهر';

  @override
  String get incomeAccount => 'حساب الدخل';

  @override
  String get selectAccount => 'اختر الحساب';

  @override
  String get incomeCategory => 'فئة الدخل';

  @override
  String get selectCategory => 'اختر الفئة';

  @override
  String get data => 'البيانات';

  @override
  String get exportData => 'تصدير البيانات';

  @override
  String get exportDataSubtitle => 'حفظ بياناتك بصيغة JSON';

  @override
  String get importData => 'استيراد البيانات';

  @override
  String get importDataSubtitle => 'الاستعادة من نسخة JSON الاحتياطية';

  @override
  String get resetAllData => 'مسح كل البيانات';

  @override
  String get resetAllDataSubtitle => 'حذف كل الحسابات والمعاملات والميزانيات';

  @override
  String get about => 'حول التطبيق';

  @override
  String get version => 'الإصدار';

  @override
  String get builtWith => 'مبني باستخدام';

  @override
  String exportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get invalidBackup => 'ملف النسخة الاحتياطية غير صالح أو فارغ.';

  @override
  String get importBackup => 'استيراد نسخة احتياطية';

  @override
  String get importBackupWarning =>
      'سيؤدي هذا إلى مسح كل البيانات الحالية واستبدالها بالنسخة الاحتياطية. لا يمكن التراجع عن ذلك.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get backupRestored => 'تمت استعادة النسخة الاحتياطية بالكامل.';

  @override
  String importedRecords(int count) {
    return 'تم استيراد $count سجل بنجاح.';
  }

  @override
  String importFailed(String error) {
    return 'فشل الاستيراد: $error';
  }

  @override
  String get resetAllDataWarning =>
      'سيؤدي هذا إلى حذف كل حساباتك ومعاملاتك وميزانياتك وإعداداتك. لا يمكن التراجع عن ذلك.';

  @override
  String get allDataReset => 'تم مسح كل البيانات';

  @override
  String get reset => 'مسح';

  @override
  String get toolsMoney => 'المال';

  @override
  String get toolsImportExport => 'الاستيراد والتصدير';

  @override
  String get toolsSecurity => 'الأمان والنسخ الاحتياطي';

  @override
  String get exchangeRates => 'أسعار الصرف';

  @override
  String get exchangeRatesSubtitle => 'المصادر والتواريخ والتعديلات اليدوية';

  @override
  String get manageAccounts => 'إدارة الحسابات';

  @override
  String get manageAccountsSubtitle =>
      'تعديل الحسابات وتجميعها وأرشفتها وتسوية أرصدتها';

  @override
  String get savedTemplates => 'قوالب المعاملات المحفوظة';

  @override
  String get savedTemplatesSubtitle => 'أعد استخدام القيود المتكررة';

  @override
  String get subcategories => 'الفئات الفرعية';

  @override
  String get subcategoriesSubtitle => 'قسّم الفئات إلى مجموعات أدق';

  @override
  String get receiptAttachments => 'مرفقات الإيصالات';

  @override
  String get receiptAttachmentsSubtitle => 'صور وملفات مرتبطة بالقيود';

  @override
  String get reportingMonthStarts => 'يبدأ شهر التقارير في';

  @override
  String dayNumber(int day) {
    return 'اليوم $day';
  }

  @override
  String get reportingMonth => 'شهر التقارير';

  @override
  String get startDayRange => 'يوم البداية (1–28)';

  @override
  String get chooseDayRange => 'اختر يومًا من 1 إلى 28';

  @override
  String get importFromApps => 'الاستيراد من تطبيقات أخرى';

  @override
  String get importFromAppsSubtitle =>
      'Money Manager وWallet وMonefy وSpendee وYNAB وملفات CSV البنكية وOFX وQIF وExcel وكشوف PDF · راجع قبل إضافة أي شيء';

  @override
  String get exportCsv => 'تصدير المعاملات بصيغة CSV';

  @override
  String get exportCsvSubtitle => 'يفتح في أي تطبيق جداول';

  @override
  String get paymentReminders => 'تذكيرات الدفع';

  @override
  String get paymentRemindersSubtitle =>
      'إشعارات محلية للمدفوعات المتوقعة وتواريخ الاستحقاق';

  @override
  String get paymentRemindersEnabled => 'تم تفعيل تذكيرات الدفع';

  @override
  String get deviceLock => 'قفل التطبيق ببصمة الجهاز';

  @override
  String get deviceLockOn => 'مفعّل · اضغط للإيقاف';

  @override
  String get deviceLockOff => 'متوقف · اضغط للتفعيل';

  @override
  String get setUpPasscodeFirst => 'أعدّ رمز مرور الجهاز أولًا';

  @override
  String get changeAppLockReason => 'تغيير قفل تطبيق Flourish';

  @override
  String get stockApiKey => 'مفتاح API لأسعار الأسهم';

  @override
  String get stockApiKeySubtitle =>
      'مفتاح Alpha Vantage اختياري · محفوظ بأمان على هذا الجهاز';

  @override
  String get alphaVantageKey => 'مفتاح Alpha Vantage API';

  @override
  String get personalApiKey => 'مفتاح API الشخصي';

  @override
  String get exportBackup => 'تصدير نسخة احتياطية مشفّرة';

  @override
  String get exportBackupSubtitle =>
      'تشمل الأصول والعقود والنشاط والإعدادات والإيصالات';

  @override
  String get restoreBackup => 'استعادة نسخة احتياطية مشفّرة';

  @override
  String get restoreBackupSubtitle => 'تستبدل كل شيء بملف نسخة احتياطية';

  @override
  String get backupHistory => 'سجل النسخ الاحتياطي التلقائي';

  @override
  String get backupHistorySubtitle =>
      'سبع نسخ يومية محلية · تبقى على هذا الجهاز';

  @override
  String get save => 'حفظ';

  @override
  String enterField(String field) {
    return 'أدخل $field';
  }

  @override
  String get owedCaps => 'مستحق';

  @override
  String get creditBalanceCaps => 'رصيد دائن';

  @override
  String get nothingOwedCaps => 'لا يوجد مستحق';

  @override
  String get noPaymentAccounts => 'لا توجد حسابات بنكية أو محافظ أو بطاقات';

  @override
  String get addOneFromAccounts => 'أضف حسابًا من صفحة الحسابات أولًا';

  @override
  String get searchTransactionsHint => 'ابحث في المعاملات...';

  @override
  String get all => 'الكل';

  @override
  String get searchTransactions => 'البحث في المعاملات';

  @override
  String get searchSubtitle => 'اكتب للبحث بالملاحظة أو النوع';

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String get unlockReason => 'افتح أموالك في Flourish';

  @override
  String get authCancelled => 'تم إلغاء التحقق';

  @override
  String get unlockToContinue => 'افتح القفل بالتحقق من الجهاز للمتابعة.';

  @override
  String get financesLocked => 'أموالك مقفلة.';

  @override
  String get unlock => 'فتح القفل';

  @override
  String get screenshotAiTitle => 'قراءة لقطات الشاشة بالذكاء الاصطناعي؟';

  @override
  String screenshotAiBody(String provider) {
    return 'لا يستطيع قارئ النصوص المدمج في أندرويد قراءة العربية. عند التفعيل، تُرسل لقطة الشاشة التي تختار قراءتها بالذكاء الاصطناعي كصورة إلى $provider. لا يمكن إخفاء أجزاء من الصورة: الأسماء وأرقام البطاقات والحسابات والأرصدة الظاهرة فيها تُرسل أيضًا.';
  }

  @override
  String get freeTiersKeep => 'قد تحتفظ الخطط المجانية بما ترسله.';

  @override
  String get screenshotAiFooter =>
      'تبقى القراءة على الجهاز هي الافتراضية؛ لا يُرسل شيء حتى تضغط \"اقرأ بالذكاء الاصطناعي\". يمكنك إيقاف ذلك من إعدادات الذكاء الاصطناعي.';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get turnOn => 'تفعيل';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get pick => 'اختيار';

  @override
  String get futureDateTitle => 'التاريخ في المستقبل';

  @override
  String futureDateBody(String date) {
    return 'هذا القيد بتاريخ $date لكنه يغيّر رصيد الحساب الآن. للدفعات التي لم تحدث بعد، قد تكون الدفعة المتكررة أو التذكير أنسب.';
  }

  @override
  String get changeDate => 'تغيير التاريخ';

  @override
  String get saveAnyway => 'حفظ على أي حال';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get deleteTransactionTitle => 'حذف المعاملة؟';

  @override
  String get deleteTransactionBody =>
      'سيؤدي هذا إلى حذف المعاملة وإعادة ضبط رصيد الحساب المرتبط تلقائيًا.';

  @override
  String get keep => 'إبقاء';

  @override
  String get transactionDeleted => 'تم حذف المعاملة';

  @override
  String get undo => 'تراجع';

  @override
  String get manageAccount => 'إدارة الحساب';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get transactions => 'المعاملات';

  @override
  String get errorLoadingTransactions => 'خطأ في تحميل المعاملات';

  @override
  String get errorLoadingAccount => 'خطأ في تحميل الحساب';

  @override
  String get transaction => 'معاملة';

  @override
  String get deleteAccountTitle => 'حذف الحساب';

  @override
  String deleteAccountBody(String name) {
    return 'حذف \"$name\"؟ الحسابات التي بها معاملات يجب أرشفتها بدلًا من حذفها، حتى يبقى سجلها في تقاريرك.';
  }

  @override
  String get inThisMonth => 'الوارد هذا الشهر';

  @override
  String get outThisMonth => 'الصادر هذا الشهر';

  @override
  String get noTransactions => 'لا توجد معاملات';

  @override
  String get addTransactionToStart => 'أضف معاملة للبدء.';

  @override
  String get cardsWalletsHelp =>
      'أضف البطاقات والمحافظ التي تدفع من هذا الحساب، ليظهر في الإنفاق ما الذي دفع وتجد المدفوعات المكتشفة الحساب الصحيح.';

  @override
  String get defaultLower => 'افتراضي';

  @override
  String fxFee(String percent) {
    return 'رسوم تحويل العملة $percent%';
  }

  @override
  String get cashNoCards => 'الحسابات النقدية ليس لها بطاقات أو محافظ';

  @override
  String get addCardOrWallet => 'إضافة بطاقة أو محفظة';

  @override
  String editNamed(String name) {
    return 'تعديل $name';
  }

  @override
  String get instrumentName => 'الاسم (مثل CIB Visa)';

  @override
  String get type => 'النوع';

  @override
  String get cardNetwork => 'شبكة البطاقة';

  @override
  String get noneNotCard => 'لا شيء / ليست بطاقة';

  @override
  String get last4Digits => 'آخر 4 أرقام (تطابق رسائل البنك)';

  @override
  String get bankOrWallet => 'البنك أو المحفظة';

  @override
  String get other => 'أخرى';

  @override
  String get walletHandle => 'رقم المحفظة أو عنوان إنستاباي';

  @override
  String get foreignFeeOptional => 'رسوم المعاملات الأجنبية، % (اختياري)';

  @override
  String get defaultForAccount => 'الافتراضي لهذا الحساب';

  @override
  String get no => 'لا';

  @override
  String get yes => 'نعم';

  @override
  String get status => 'الحالة';

  @override
  String get inUse => 'قيد الاستخدام';

  @override
  String get archived => 'مؤرشف';

  @override
  String get manageCategories => 'إدارة الفئات';

  @override
  String get noCategories => 'لا توجد فئات';

  @override
  String get errorLoadingCategories => 'خطأ في تحميل الفئات';

  @override
  String get category => 'الفئة';

  @override
  String get systemCategoryLocked => 'تُستخدم للقيود التلقائية؛ لا يمكن حذفها';

  @override
  String get deleteCategory => 'حذف الفئة';

  @override
  String deleteCategoryWithTx(String name, int count, String target) {
    return '\"$name\" بها $count معاملة. سيتم نقلها إلى \"$target\"، وستُحذف ميزانيات هذه الفئة.';
  }

  @override
  String get otherIncome => 'دخل آخر';

  @override
  String deleteCategoryEmpty(String name) {
    return 'حذف \"$name\"؟ ستُحذف ميزانياتها.';
  }

  @override
  String get editCategory => 'تعديل الفئة';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get categoryName => 'اسم الفئة';

  @override
  String get icon => 'الأيقونة';

  @override
  String get color => 'اللون';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get enterName => 'يرجى إدخال اسم';

  @override
  String get categoryNameTooLong => 'استخدم 100 حرف أو أقل';

  @override
  String get categoryNameExists => 'توجد فئة بهذا الاسم بالفعل';

  @override
  String categoryTypeLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هذه الفئة تحتوي على $count معاملة، لذا لا يمكن تغيير نوعها.',
      one: 'هذه الفئة تحتوي على معاملة واحدة، لذا لا يمكن تغيير نوعها.',
    );
    return '$_temp0';
  }

  @override
  String get systemCategoryTypeFixed =>
      'تستخدم القيود التلقائية هذه الفئة، لذا نوعها ثابت';

  @override
  String get newCategory => 'جديد';

  @override
  String get noAccountsYet => 'لا توجد حسابات بعد';

  @override
  String get addFirstAccount => 'أضف أول حساب لتبدأ المتابعة.';

  @override
  String accountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حساب',
      few: '$count حسابات',
      two: 'حسابان',
      one: 'حساب واحد',
    );
    return '$_temp0';
  }

  @override
  String get errorLoadingAccounts => 'خطأ في تحميل الحسابات';

  @override
  String get addAccount => 'إضافة حساب';

  @override
  String get accountName => 'اسم الحساب';

  @override
  String get accountNameHint => 'مثال: البنك الرئيسي';

  @override
  String get amountOweNow => 'المبلغ المستحق عليك الآن';

  @override
  String get currentBalance => 'الرصيد الحالي';

  @override
  String get debtPositiveHint => 'أدخل الدين كرقم موجب؛ 0 للبطاقة المسددة';

  @override
  String get leaveEmptyZero => 'اتركه فارغًا ليكون 0';

  @override
  String get accountType => 'نوع الحساب';

  @override
  String get currency => 'العملة';

  @override
  String get cardTerms => 'شروط البطاقة';

  @override
  String get creditLimit => 'الحد الائتماني';

  @override
  String get interestPerYear => 'الفائدة % / سنويًا';

  @override
  String get statementDay => 'يوم كشف الحساب';

  @override
  String get dueDay => 'يوم الاستحقاق';

  @override
  String get cardFeesLater =>
      'يمكن إضافة الرسوم (المعاملات الأجنبية، السحب النقدي، التأخير في السداد) من صفحة البطاقة.';

  @override
  String get enterAccountName => 'يرجى إدخال اسم الحساب';

  @override
  String maxDecimals(int count) {
    return 'استخدم $count منازل عشرية كحد أقصى';
  }

  @override
  String get transfers => 'التحويلات';

  @override
  String get search => 'بحث';

  @override
  String get listView => 'عرض القائمة';

  @override
  String get calendarView => 'عرض التقويم';

  @override
  String get allAccounts => 'كل الحسابات';

  @override
  String get allCategories => 'كل الفئات';

  @override
  String showingDay(String day) {
    return 'عرض $day · إظهار الشهر كاملًا';
  }

  @override
  String get couldNotLoadTransactions => 'تعذّر تحميل المعاملات';

  @override
  String get nothingHereYet => 'لا شيء هنا بعد';

  @override
  String get noTransactionsPeriod => 'لا توجد معاملات في هذه الفترة.';

  @override
  String get previousMonth => 'الشهر السابق';

  @override
  String get chooseDateRange => 'اختر نطاق التاريخ';

  @override
  String get clearRange => 'مسح النطاق';

  @override
  String get nextMonth => 'الشهر التالي';

  @override
  String get goal => 'هدف';

  @override
  String get noGoalsYet => 'لا توجد أهداف بعد';

  @override
  String get noGoalsSubtitle => 'حدّد هدف ادخار لتبدأ متابعة تقدّمك.';

  @override
  String get errorLoadingGoals => 'خطأ في تحميل الأهداف';

  @override
  String get goalReached => 'تم بلوغ الهدف';

  @override
  String percentSaved(String percent) {
    return 'تم ادخار $percent%';
  }

  @override
  String ofTarget(String amount) {
    return 'من $amount';
  }

  @override
  String get pastDeadline => 'تجاوز الموعد';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يومًا متبقيًا',
      few: '$count أيام متبقية',
      two: 'يومان متبقيان',
      one: 'يوم واحد متبقٍ',
      zero: 'لا أيام متبقية',
    );
    return '$_temp0';
  }

  @override
  String get deleteGoal => 'حذف الهدف';

  @override
  String get deleteGoalTitle => 'حذف الهدف؟';

  @override
  String deleteGoalBody(String name) {
    return 'سيتم حذف \"$name\" وتقدّمه.';
  }

  @override
  String addToGoal(String name) {
    return 'إضافة إلى \"$name\"';
  }

  @override
  String get amount => 'المبلغ';

  @override
  String get contribute => 'إضافة مبلغ';

  @override
  String get newSavingsGoal => 'هدف ادخار جديد';

  @override
  String get goalName => 'اسم الهدف';

  @override
  String get goalNameHint => 'مثال: حاسوب جديد';

  @override
  String get targetAmount => 'المبلغ المستهدف';

  @override
  String get deadline => 'الموعد النهائي';

  @override
  String get linkedAccount => 'الحساب المرتبط';

  @override
  String get createGoal => 'إنشاء الهدف';

  @override
  String get addCashOrBankFirst => 'أضف حسابًا نقديًا أو بنكيًا أولًا';

  @override
  String get apiKeyRemoved => 'تمت إزالة مفتاح API';

  @override
  String get apiKeySaved => 'تم حفظ مفتاح API';

  @override
  String get saveApiKeyFirst => 'احفظ مفتاح API أولًا';

  @override
  String get noModelsForKey => 'لا توجد نماذج متاحة لهذا المفتاح';

  @override
  String get addAiConfigFirst =>
      'أضف عنوان URL الأساسي والنموذج ومفتاح API أولًا';

  @override
  String connectedTo(String model) {
    return 'متصل بـ $model';
  }

  @override
  String get connectedNoJson =>
      'تم الاتصال، لكن النموذج لم يلتزم بتعليمات JSON. جرّب نموذجًا آخر.';

  @override
  String get aiAssistant => 'المساعد الذكي';

  @override
  String get useAiWhenUnsure => 'استخدم الذكاء الاصطناعي عند عدم التأكد';

  @override
  String get useAiWhenUnsureSubtitle =>
      'يقرأ Flourish التنبيهات على هاتفك أولًا. تُرسل إلى الذكاء الاصطناعي فقط الرسائل التي لا يستطيع قراءتها بثقة.';

  @override
  String get provider => 'المزوّد';

  @override
  String freeTier(String provider) {
    return '$provider · خطة مجانية';
  }

  @override
  String get baseUrl => 'عنوان URL الأساسي';

  @override
  String get model => 'النموذج';

  @override
  String get chooseModel => 'اختر النموذج';

  @override
  String get apiKey => 'مفتاح API';

  @override
  String get apiKeySavedHint => '•••••••• (محفوظ)';

  @override
  String get pasteYourKey => 'الصق مفتاحك';

  @override
  String get saveKey => 'حفظ المفتاح';

  @override
  String get keyStorageNote =>
      'يُحفظ في سلسلة مفاتيح الجهاز. اتركه فارغًا واحفظ لإزالته.';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String askBelowConfidence(int percent) {
    return 'اسأل الذكاء الاصطناعي عندما تقل الثقة عن $percent%';
  }

  @override
  String percentConfidence(int percent) {
    return 'ثقة $percent%';
  }

  @override
  String get higherSendsMore =>
      'القيمة الأعلى ترسل رسائل أكثر إلى الذكاء الاصطناعي (دقة أفضل، طلبات أكثر).';

  @override
  String get aiSuggestCategories =>
      'السماح للذكاء الاصطناعي باقتراح فئات جديدة';

  @override
  String get aiSuggestCategoriesSubtitle =>
      'تظهر الفئات الجديدة مع ✨ ولا تُنشأ إلا عند الحفظ.';

  @override
  String get hidePersonalData => 'إخفاء البيانات الشخصية';

  @override
  String get hidePersonalDataFree =>
      'مفعّل دائمًا مع المزوّدين المجانيين الذين قد يحتفظون بالطلبات.';

  @override
  String get hidePersonalDataSubtitle =>
      'يخفي أرقام الحسابات والبطاقات والهواتف والبريد الإلكتروني قبل الإرسال.';

  @override
  String get readArabicScreenshots =>
      'قراءة لقطات الشاشة العربية بالذكاء الاصطناعي';

  @override
  String providerNoImages(String provider) {
    return 'لا يستطيع $provider قراءة الصور؛ اختر نموذجًا يستطيع ذلك مثل Gemini.';
  }

  @override
  String get sendsImageUnmasked =>
      'يرسل الصورة نفسها دون إخفاء عند الضغط على \"اقرأ بالذكاء الاصطناعي\" في الاستيراد الذكي.';

  @override
  String aiUsageThisMonth(String requests, String tokens) {
    return 'هذا الشهر: $requests طلب · $tokens رمز';
  }

  @override
  String get aiConnection => 'الاتصال';

  @override
  String get aiBehaviour => 'السلوك';

  @override
  String get aiUsage => 'الاستخدام';

  @override
  String importedSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم استيراد $count معاملة',
      few: 'تم استيراد $count معاملات',
      two: 'تم استيراد معاملتين',
      one: 'تم استيراد معاملة واحدة',
      zero: 'لم يتم استيراد أي معاملة',
    );
    return '$_temp0';
  }

  @override
  String skippedCount(int count) {
    return 'تم تخطي $count';
  }

  @override
  String get reconcileOpening => 'سوِّ الأرصدة الافتتاحية إذا لزم الأمر.';

  @override
  String get reviewImport => 'مراجعة الاستيراد';

  @override
  String importCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استيراد $count معاملة',
      few: 'استيراد $count معاملات',
      two: 'استيراد معاملتين',
      one: 'استيراد معاملة واحدة',
      zero: 'استيراد',
    );
    return '$_temp0';
  }

  @override
  String newCount(int count) {
    return '$count جديدة';
  }

  @override
  String alreadyImportedCount(int count) {
    return '$count مستوردة مسبقًا';
  }

  @override
  String possibleDuplicatesCount(int count) {
    return '$count مكررة محتملة';
  }

  @override
  String unreadableCount(int count) {
    return '$count غير مقروءة';
  }

  @override
  String get unverifiedLayout =>
      'صُمّم هذا التنسيق من الوثائق وليس من ملف تصدير حقيقي. تحقّق من بعض الصفوف أدناه قبل الاستيراد.';

  @override
  String andMore(int count) {
    return '…و$count أخرى';
  }

  @override
  String accountInFile(String name, String rows) {
    return '«$name» في الملف · $rows';
  }

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صف',
      few: '$count صفوف',
      two: 'صفان',
      one: 'صف واحد',
    );
    return '$_temp0';
  }

  @override
  String createNewAccount(String currency) {
    return 'إنشاء حساب جديد ($currency)';
  }

  @override
  String get categoriesNotInApp => 'فئات غير موجودة في Flourish';

  @override
  String get chooseCategoryDest =>
      'اختر وجهة كل فئة. تحتفظ الفئات الجديدة بالفئة الأم من الملف.';

  @override
  String createNamed(String name) {
    return 'إنشاء «$name»';
  }

  @override
  String get changePerAccount => 'التغيير لكل حساب';

  @override
  String get nothingSelected => 'لم يتم اختيار شيء';

  @override
  String get alreadyImported => 'مستوردة مسبقًا';

  @override
  String get possibleDuplicate => 'مكررة محتملة';

  @override
  String get cannotImport => 'لا يمكن الاستيراد';

  @override
  String moreRowsFollow(int count) {
    return '$count صفوف أخرى تتبع الاختيارات نفسها';
  }

  @override
  String get noTextTryAi =>
      'لم يُعثر على نص مقروء. للعربية، جرّب \"اقرأ بالذكاء الاصطناعي\".';

  @override
  String get noTextTypeInstead =>
      'لم يُعثر على نص مقروء. اكتب التنبيه أو الصقه بدلًا من ذلك.';

  @override
  String textRecognitionFailed(String error) {
    return 'فشل التعرّف على النص: $error';
  }

  @override
  String providerNoImagesSettings(String provider) {
    return 'لا يستطيع $provider قراءة الصور. اختر نموذجًا يستطيع ذلك مثل Gemini من إعدادات الذكاء الاصطناعي.';
  }

  @override
  String get aiNoText => 'لم يجد الذكاء الاصطناعي نصًا مقروءًا في هذه الصورة.';

  @override
  String modelCannotReadImage(String error) {
    return 'لم يتمكن هذا النموذج من قراءة الصورة ($error). اختر نموذجًا يقرأ الصور من إعدادات الذكاء الاصطناعي.';
  }

  @override
  String aiReadingFailed(String error) {
    return 'فشلت القراءة بالذكاء الاصطناعي: $error';
  }

  @override
  String get aiUnavailableOnDevice =>
      'الذكاء الاصطناعي غير متاح، تُعرض نتائج الجهاز';

  @override
  String get noNewPayments => 'لم يُعثر على مدفوعات جديدة';

  @override
  String paymentsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دفعة جاهزة للمراجعة',
      few: '$count دفعات جاهزة للمراجعة',
      two: 'دفعتان جاهزتان للمراجعة',
      one: 'دفعة واحدة جاهزة للمراجعة',
    );
    return '$_temp0';
  }

  @override
  String skippedNotices(int count) {
    return 'تم تخطي $count (رموز أو عروض أو إشعارات أو مضافة مسبقًا)';
  }

  @override
  String couldNotAnalyse(String error) {
    return 'تعذّر التحليل: $error';
  }

  @override
  String get reviewSharedScreenshot => 'مراجعة لقطة شاشة الدفع المشتركة';

  @override
  String get pasteAlertsTitle => 'الصق تنبيهات البنك أو المحفظة أو Apple Pay';

  @override
  String get pasteAlertsBody =>
      'الصق تنبيهًا واحدًا أو عدة تنبيهات مرة واحدة. يُقرأ كل منها على هاتفك ويُضاف إلى المدفوعات للمراجعة.';

  @override
  String get keepAsReceipt => 'الاحتفاظ بهذه الصورة كإيصال';

  @override
  String get readWithAiArabic => 'اقرأ بالذكاء الاصطناعي (عربي)';

  @override
  String get alertText => 'نص التنبيه';

  @override
  String alertTextFrom(String source) {
    return 'نص التنبيه (من $source)';
  }

  @override
  String get alertExample =>
      'مثال: Apple Pay: البطاقة 1234 أنفقت 24.90 USD في Starbucks';

  @override
  String get paste => 'لصق';

  @override
  String get photo => 'صورة';

  @override
  String get analyze => 'تحليل';

  @override
  String get aiSecondReading =>
      'تحصل التنبيهات غير الواضحة على قراءة ثانية بالذكاء الاصطناعي.';

  @override
  String get readOnPhone =>
      'تُقرأ على هاتفك. أضف مزوّد ذكاء اصطناعي للتنبيهات الصعبة.';

  @override
  String get aiSettings => 'إعدادات الذكاء الاصطناعي';

  @override
  String get setUp => 'إعداد';

  @override
  String get obligations => 'الالتزامات';

  @override
  String get reports => 'التقارير';

  @override
  String get tools => 'الأدوات';

  @override
  String get pricesRefreshed => 'تم تحديث الأسعار';

  @override
  String get refreshPrices => 'تحديث الأسعار';

  @override
  String get couldNotLoadNetWorth => 'تعذّر تحميل صافي الثروة.';

  @override
  String get netWorthCaps => 'صافي الثروة';

  @override
  String get knownNetWorthCaps => 'صافي الثروة المعروف';

  @override
  String get trendLineLater => 'يظهر خط الاتجاه بعد بضعة أيام من المتابعة.';

  @override
  String get assets => 'الأصول';

  @override
  String get debts => 'الديون';

  @override
  String get liquid => 'السيولة';

  @override
  String get pricesMissing =>
      'بعض الأسعار أو أسعار الصرف غير متوفرة. تشمل الإجماليات القيم المعروفة فقط.';

  @override
  String get pricesStale => 'بعض الأسعار أقدم من 72 ساعة. اسحب للأسفل للتحديث.';

  @override
  String get reportingCurrency => 'عملة التقارير';

  @override
  String get pageNotFoundTitle => 'الصفحة غير موجودة';

  @override
  String get notFound => 'غير موجود';

  @override
  String get destinationUnavailable => 'هذه الوجهة غير متاحة أو ربما نُقلت.';

  @override
  String get backHome => 'العودة للرئيسية';

  @override
  String get somethingWentWrong => 'حدث خطأ ما';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get newTransaction => 'معاملة جديدة';

  @override
  String get noAccountsAddFirst => 'لا توجد حسابات. يرجى إضافة حساب أولًا.';

  @override
  String get needTwoAccounts => 'أضف حسابين على الأقل للتحويل.';

  @override
  String get from => 'من';

  @override
  String get to => 'إلى';

  @override
  String amountReceivedIn(String currency) {
    return 'المبلغ المستلم بـ $currency';
  }

  @override
  String get whatArrived => 'ما وصل فعليًا بعد التحويل';

  @override
  String transferFeeIn(String currency) {
    return 'رسوم التحويل بـ $currency (اختياري)';
  }

  @override
  String get account => 'الحساب';

  @override
  String get refundFor => 'استرداد لـ';

  @override
  String get merchantOptional => 'التاجر أو المستفيد (اختياري)';

  @override
  String get addNote => 'أضف ملاحظة';

  @override
  String get addRefund => 'إضافة استرداد';

  @override
  String get addExpense => 'إضافة مصروف';

  @override
  String get addIncome => 'إضافة دخل';

  @override
  String get paidWith => 'الدفع بواسطة';

  @override
  String overCardLimit(String amount) {
    return 'يتجاوز هذا حد البطاقة بمقدار $amount.';
  }

  @override
  String get isRefund => 'هذا استرداد';

  @override
  String get isRefundSubtitle => 'أموال مستردة تقلّل الإنفاق';

  @override
  String get paidOtherCurrency => 'مدفوع بعملة أخرى';

  @override
  String paidOtherCurrencySubtitle(String currency) {
    return 'مثل الدفع بالدولار عبر الإنترنت أو بالخارج، مخصوم بـ $currency';
  }

  @override
  String priceIn(String currency) {
    return 'السعر بـ $currency';
  }

  @override
  String get feeIncluded => 'المبلغ المخصوم يشمل رسوم البنك بالفعل';

  @override
  String chargedAmountNote(String account) {
    return 'المبلغ أعلاه هو ما خُصم من $account. حدّد رسوم المعاملات الأجنبية على البطاقة لمتابعتها.';
  }

  @override
  String fxFeeInside(String percent, String fee, String charged) {
    return 'رسوم المعاملات الأجنبية $percent%: $fee ضمن $charged. استخدم المبلغ الوارد في كشف حسابك عند توفره.';
  }

  @override
  String fxFeeOnTop(String percent, String fee, String charged) {
    return 'رسوم المعاملات الأجنبية $percent%: $fee فوق $charged. استخدم المبلغ الوارد في كشف حسابك عند توفره.';
  }

  @override
  String get selectAccountError => 'يرجى اختيار حساب';

  @override
  String get selectDestinationError => 'يرجى اختيار الحساب المستلم';

  @override
  String get sameAccountsError => 'يجب أن يختلف الحساب المرسل عن المستلم';

  @override
  String get selectCategoryError => 'يرجى اختيار فئة';

  @override
  String get chooseCurrency => 'اختر عملة';

  @override
  String get transferEditNote =>
      'تنطبق التغييرات على الحسابين المرتبطين ورسوم التحويل.';

  @override
  String get editTransfer => 'تعديل التحويل';

  @override
  String get deleteTransfer => 'حذف التحويل';

  @override
  String get editTransaction => 'تعديل المعاملة';

  @override
  String get refundReduces => 'استرداد · يقلّل الإنفاق في فئته';

  @override
  String get editLinkedTransfer => 'تعديل التحويل المرتبط';

  @override
  String get fromAccount => 'من حساب';

  @override
  String get toAccount => 'إلى حساب';

  @override
  String get sourceAmount => 'المبلغ المرسل';

  @override
  String get destinationAmount => 'المبلغ المستلم';

  @override
  String get sourceCurrencyFee => 'الرسوم بعملة المصدر';

  @override
  String get date => 'التاريخ';

  @override
  String get note => 'ملاحظة';

  @override
  String get deleteTransactionTitle2 => 'حذف المعاملة';

  @override
  String get deleteTransactionConfirm =>
      'هل أنت متأكد؟ سيتم تعديل رصيد الحساب.';

  @override
  String paidOriginal(String currency, String amount) {
    return 'تم دفع $currency $amount.';
  }

  @override
  String paidOriginalWithFee(String currency, String amount, String percent) {
    return 'تم دفع $currency $amount؛ تُحسب رسوم المعاملات الأجنبية $percent% على هذا المبلغ.';
  }

  @override
  String noRateForDate(String from, String to) {
    return 'لا يوجد سعر صرف $from←$to لهذا التاريخ. أدخل المبلغ بـ $to.';
  }

  @override
  String convertedAtRate(String from, String amount, String to) {
    return 'تم تحويل $from $amount إلى $to بسعر هذا التاريخ. تحقّق من مطابقته للمبلغ المخصوم.';
  }

  @override
  String get recurringPayment => 'دفعة متكررة';

  @override
  String get recurringTransactions => 'المعاملات المتكررة';

  @override
  String get noRecurring => 'لا توجد معاملات متكررة';

  @override
  String get setUpAutomatic => 'أعدّ معاملات تلقائية';

  @override
  String get errorLoading => 'خطأ في التحميل';

  @override
  String get pausedCaps => 'متوقفة مؤقتًا';

  @override
  String frequencyNext(String frequency, String date) {
    return '$frequency · التالية $date';
  }

  @override
  String notPosted(String reason) {
    return 'لم تُسجّل: $reason';
  }

  @override
  String get recurringOptions => 'خيارات التكرار';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get resume => 'استئناف';

  @override
  String get daily => 'يوميًا';

  @override
  String get weekly => 'أسبوعيًا';

  @override
  String get monthly => 'شهريًا';

  @override
  String get yearly => 'سنويًا';

  @override
  String get newRecurring => 'معاملة متكررة جديدة';

  @override
  String get editRecurring => 'تعديل المعاملة المتكررة';

  @override
  String get toAccountHint => 'إلى حساب (مثل بطاقتك الائتمانية أو الادخار)';

  @override
  String get chargedTo => 'يُخصم من';

  @override
  String get notSet => 'غير محدد';

  @override
  String get frequency => 'التكرار';

  @override
  String get firstOccurrence => 'أول مرة';

  @override
  String get nextOccurrence => 'المرة التالية';

  @override
  String get endsOptional => 'ينتهي (اختياري)';

  @override
  String get noEndDate => 'بدون تاريخ انتهاء';

  @override
  String get never => 'أبدًا';

  @override
  String get noteOptional => 'ملاحظة (اختياري)';

  @override
  String get createRecurring => 'إنشاء معاملة متكررة';

  @override
  String get chooseTransferTarget => 'اختر الحساب المحوَّل إليه';

  @override
  String get selectAccountCategory => 'يرجى اختيار الحساب والفئة';

  @override
  String get startInPast => 'تاريخ البدء في الماضي';

  @override
  String get tooManyMissed =>
      'هناك أكثر من 24 دفعة قبل اليوم. سيبدأ الجدول من تاريخه التالي؛ أضف الدفعات الأقدم يدويًا إذا احتجت إليها.';

  @override
  String missedPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'هناك $count دفعة قبل اليوم. هل تسجّلها الآن أم تبدأ من التاريخ التالي؟',
      few:
          'هناك $count دفعات قبل اليوم. هل تسجّلها الآن أم تبدأ من التاريخ التالي؟',
      two: 'هناك دفعتان قبل اليوم. هل تسجّلهما الآن أم تبدأ من التاريخ التالي؟',
      one:
          'هناك دفعة واحدة قبل اليوم. هل تسجّلها الآن أم تبدأ من التاريخ التالي؟',
    );
    return '$_temp0';
  }

  @override
  String get startFromNext => 'البدء من التاريخ التالي';

  @override
  String postCount(int count) {
    return 'تسجيل $count';
  }

  @override
  String get noBudgets => 'لا توجد ميزانيات';

  @override
  String get noBudgetsSubtitle => 'أنشئ ميزانية لمتابعة حدود إنفاقك.';

  @override
  String get createABudget => 'إنشاء ميزانية';

  @override
  String activeBudgets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ميزانية نشطة',
      few: '$count ميزانيات نشطة',
      two: 'ميزانيتان نشطتان',
      one: 'ميزانية نشطة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get errorLoadingBudgets => 'خطأ في تحميل الميزانيات';

  @override
  String get deleteBudget => 'حذف الميزانية';

  @override
  String get deleteBudgetConfirm => 'هل أنت متأكد من حذف هذه الميزانية؟';

  @override
  String budgetUsedPercent(String percent) {
    return 'تم استخدام $percent% من الميزانية';
  }

  @override
  String get budgetOptions => 'خيارات الميزانية';

  @override
  String budgetConfirmCurrency(String amount) {
    return 'الميزانية $amount · أكّد عملتها الأصلية من خلال التعديل.';
  }

  @override
  String overBy(String amount) {
    return 'تجاوز بمقدار $amount';
  }

  @override
  String remainingUsed(String amount, String percent) {
    return 'متبقٍ $amount · مستخدم $percent%';
  }

  @override
  String recordsNeedRates(int count) {
    return '$count سجل يحتاج إلى أسعار صرف؛ الإنفاق غير مكتمل.';
  }

  @override
  String get previousBudgetPeriod => 'فترة الميزانية السابقة';

  @override
  String get nextBudgetPeriod => 'فترة الميزانية التالية';

  @override
  String get editBudget => 'تعديل الميزانية';

  @override
  String get originalBudgetCurrency => 'عملة الميزانية الأصلية';

  @override
  String get budgetAmount => 'مبلغ الميزانية';

  @override
  String get startDate => 'تاريخ البدء';

  @override
  String get period => 'الفترة';

  @override
  String get createBudget => 'إنشاء الميزانية';

  @override
  String get budgetAmountTitle => 'مبلغ الميزانية';

  @override
  String budgetExists(String period) {
    return 'لهذه الفئة ميزانية ($period) بالفعل. عدّلها بدلًا من ذلك.';
  }

  @override
  String cardPaymentNote(String name) {
    return 'سداد البطاقة: $name';
  }

  @override
  String get cardInterest => 'فائدة البطاقة';

  @override
  String get annualCardFee => 'الرسوم السنوية للبطاقة';

  @override
  String get cardFee => 'رسوم البطاقة';

  @override
  String get charge => 'رسوم';

  @override
  String get interest => 'الفائدة';

  @override
  String get latePaymentFee => 'رسوم التأخر في السداد';

  @override
  String get annualFee => 'الرسوم السنوية';

  @override
  String get otherBankFee => 'رسوم بنكية أخرى';

  @override
  String get cardDetails => 'تفاصيل البطاقة';

  @override
  String get cardDetailsHelp =>
      'أضف الحد ويومي كشف الحساب والاستحقاق والرسوم لترى الرصيد المتاح والحد الأدنى للسداد والفائدة.';

  @override
  String get setUpCardTerms => 'إعداد شروط البطاقة';

  @override
  String get credit => 'الائتمان';

  @override
  String get editCardTerms => 'تعديل شروط البطاقة';

  @override
  String get available => 'المتاح';

  @override
  String get limit => 'الحد';

  @override
  String limitUsed(String percent) {
    return 'تم استخدام $percent% من الحد';
  }

  @override
  String get under30Tip => 'إبقاؤه أقل من 30% يحسّن تصنيفك الائتماني';

  @override
  String overLimitBy(String amount) {
    return 'تجاوز الحد بمقدار $amount';
  }

  @override
  String get lastStatement => 'آخر كشف حساب';

  @override
  String get stillToPay => 'المتبقي للسداد';

  @override
  String get minimumDue => 'الحد الأدنى المستحق';

  @override
  String minimumDueBy(String date) {
    return 'الحد الأدنى المستحق قبل $date';
  }

  @override
  String get interestIfUnpaid => 'الفائدة إن لم تُسدَّد (تقديرية)';

  @override
  String get cashAdvances => 'السحوبات النقدية';

  @override
  String get payCard => 'سداد البطاقة';

  @override
  String get interestOrFee => 'فائدة أو رسوم';

  @override
  String termsOf(String name) {
    return 'شروط $name';
  }

  @override
  String creditLimitIn(String currency) {
    return 'الحد الائتماني ($currency)';
  }

  @override
  String get purchaseInterest => 'فائدة المشتريات، % سنويًا';

  @override
  String get statementClosingDay => 'يوم إغلاق كشف الحساب (1–31)';

  @override
  String get paymentDueDay => 'يوم استحقاق السداد (1–31)';

  @override
  String get minimumPaymentPercent => 'الحد الأدنى للسداد، % من الكشف';

  @override
  String minimumPaymentAtLeast(String currency) {
    return 'الحد الأدنى للسداد لا يقل عن ($currency)';
  }

  @override
  String get foreignFeePercent => 'رسوم المعاملات الأجنبية، %';

  @override
  String get cashAdvanceFee => 'رسوم السحب النقدي، %';

  @override
  String cashAdvanceFeeMin(String currency) {
    return 'رسوم السحب النقدي لا تقل عن ($currency)';
  }

  @override
  String get cashAdvanceInterest => 'فائدة السحب النقدي، % سنويًا';

  @override
  String latePaymentFeeIn(String currency) {
    return 'رسوم التأخر في السداد ($currency)';
  }

  @override
  String addAccountToPayFrom(String currency) {
    return 'أضف حسابًا بنكيًا أو نقديًا بعملة $currency للسداد منه';
  }

  @override
  String payNamed(String name) {
    return 'سداد $name';
  }

  @override
  String get payFrom => 'السداد من';

  @override
  String amountMinimum(String amount) {
    return 'المبلغ (الحد الأدنى $amount)';
  }

  @override
  String get pay => 'سداد';

  @override
  String chargeOn(String name) {
    return 'رسوم على $name';
  }

  @override
  String amountIn(String currency) {
    return 'المبلغ ($currency)';
  }

  @override
  String get statementDate => 'تاريخ كشف الحساب';

  @override
  String get buy => 'شراء';

  @override
  String get sell => 'بيع';

  @override
  String get setPrice => 'تحديد السعر';

  @override
  String get useFeed => 'استخدام الأسعار التلقائية';

  @override
  String get linkMortgage => 'ربط الرهن العقاري';

  @override
  String get adjust => 'تعديل';

  @override
  String get split => 'تقسيم';

  @override
  String get activity => 'النشاط';

  @override
  String get actualIncomeInAccount => 'الدخل الفعلي بعملة الحساب';

  @override
  String pricePerUnitIn(String currency) {
    return 'سعر الوحدة بـ $currency';
  }

  @override
  String get addHolding => 'إضافة أصل';

  @override
  String get addHoldingHelp =>
      'أضف ذهبًا أو استثمارات أو عقارات أو عملات مشفرة أو أي أصل آخر. لا تغيّر الأصول الحالية رصيدك النقدي.';

  @override
  String get missingPrice => 'السعر غير متوفر';

  @override
  String get needsPrice => 'يحتاج إلى سعر';

  @override
  String costUnknown(String amount, String currency) {
    return 'التكلفة $amount $currency';
  }

  @override
  String get unknown => 'غير معروفة';

  @override
  String get assetName => 'اسم الأصل';

  @override
  String get assetClass => 'فئة الأصل';

  @override
  String get quantityGrams => 'الكمية / الوزن بالجرام';

  @override
  String get acquisitionCurrency => 'عملة الشراء';

  @override
  String get totalCostShare => 'إجمالي تكلفة حصتك (اتركه فارغًا إن لم تعرفه)';

  @override
  String get tickerSymbol => 'رمز السهم / العملة المشفرة';

  @override
  String get exchangeHint => 'البورصة (EGX، NASDAQ، إلخ)';

  @override
  String get whereHeld => 'مكان الحفظ';

  @override
  String get ownershipFraction => 'نسبة الملكية (1 = 100%)';

  @override
  String get goldKarat => 'عيار الذهب';

  @override
  String get priceSource => 'مصدر السعر';

  @override
  String get datedManualPrices => 'أسعار يدوية مؤرّخة';

  @override
  String get freeMarketFeed => 'أسعار السوق المجانية عند توفرها';

  @override
  String get currentResalePrice =>
      'سعر إعادة البيع الحالي للوحدة / الجرام (اختياري)';

  @override
  String get openingDate => 'تاريخ البداية';

  @override
  String get priceMustBePositive => 'يجب أن يكون السعر موجبًا';

  @override
  String valueNamed(String name) {
    return 'تقييم $name';
  }

  @override
  String get resalePricePerUnit => 'سعر إعادة البيع للوحدة / الجرام';

  @override
  String get quoteCurrency => 'عملة السعر';

  @override
  String get quoteDate => 'تاريخ السعر';

  @override
  String get source => 'المصدر';

  @override
  String ownershipLine(String quantity, String unit, String percent) {
    return '$quantity $unit · الملكية $percent%';
  }

  @override
  String get unrealizedGainCaps => 'الربح غير المحقق';

  @override
  String get gainUnknown => 'غير معروف — التكلفة أو السعر غير متوفر';

  @override
  String get linkPropertyMortgage => 'ربط العقار بالرهن';

  @override
  String get existingObligation =>
      'التزام قائم (يُحسب مرة واحدة في صافي الثروة)';

  @override
  String get noLinkedMortgage => 'لا يوجد رهن مرتبط';

  @override
  String get manualAppraisals => 'يستخدم هذا الأصل تقييمات يدوية مؤرّخة.';

  @override
  String get adjustHoldingAudit => 'تعديل الأصل مع سجل تدقيق';

  @override
  String get correctQuantity => 'الكمية الصحيحة';

  @override
  String get totalAcquisitionCost =>
      'إجمالي تكلفة الشراء (اتركه فارغًا إن لم تعرفه)';

  @override
  String get custodyLocation => 'الحفظ / الموقع';

  @override
  String get adjustReason => 'سبب التعديل';

  @override
  String get stockSplit => 'تقسيم الأسهم / تعديل الكمية';

  @override
  String get newUnitsPerOld => 'الوحدات الجديدة لكل وحدة قديمة';

  @override
  String get createCashAccountFirst => 'أنشئ حسابًا نقديًا أولًا';

  @override
  String get cashAccount => 'الحساب النقدي';

  @override
  String get incomeType => 'نوع الدخل';

  @override
  String get dividend => 'توزيعات أرباح';

  @override
  String get rent => 'إيجار';

  @override
  String get quantity => 'الكمية';

  @override
  String get actualGrossCash => 'إجمالي النقد الفعلي بعملة الحساب (اختياري)';

  @override
  String get feeInAccount => 'الرسوم بعملة الحساب';

  @override
  String get transactionDate => 'تاريخ المعاملة';

  @override
  String activityOf(String name) {
    return 'نشاط $name';
  }

  @override
  String get unknownCost => 'تكلفة غير معروفة';

  @override
  String gainLabel(String amount) {
    return 'الربح $amount';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get assetGold => 'ذهب';

  @override
  String get assetStock => 'أسهم';

  @override
  String get assetFund => 'صندوق استثمار';

  @override
  String get assetCrypto => 'عملات مشفرة';

  @override
  String get assetProperty => 'عقار';

  @override
  String get assetCustom => 'أصل آخر';

  @override
  String ratesMatures(String rate, String date) {
    return '$rate% · يستحق في $date';
  }

  @override
  String get contractDeposit => 'وديعة';

  @override
  String get contractCertificate => 'شهادة';

  @override
  String get contractLoan => 'قرض';

  @override
  String get contractReceivable => 'مستحقات لك';

  @override
  String get contractCreditCard => 'بطاقة ائتمان';

  @override
  String get addContractOrDebt => 'إضافة عقد أو دين';

  @override
  String get expectedPaymentsNote =>
      'لا تغيّر المدفوعات المتوقعة النقد حتى تؤكد الاستلام أو الدفع.';

  @override
  String get owed => 'مستحق';

  @override
  String get principal => 'أصل المبلغ';

  @override
  String get addContractObligation => 'إضافة عقد أو التزام';

  @override
  String get name => 'الاسم';

  @override
  String get existingPrincipal => 'المبلغ القائم / الأصل المستثمر حاليًا';

  @override
  String get annualInterestCoupon => 'الفائدة / العائد السنوي (%)';

  @override
  String get counterparty => 'البنك / الشخص / المُقرض';

  @override
  String get interestConvention => 'طريقة حساب الفائدة';

  @override
  String get flatRate => 'سعر سنوي ثابت / عوائد دورية';

  @override
  String get reducingBalance => 'رصيد متناقص، أقساط متساوية';

  @override
  String get manualSchedule => 'أدخل جدولًا متفقًا عليه يدويًا';

  @override
  String get paymentsPerYear => 'عدد الدفعات في السنة';

  @override
  String get quarterly => 'ربع سنوي';

  @override
  String get halfYearly => 'نصف سنوي';

  @override
  String get maturityDate => 'تاريخ الاستحقاق / الانتهاء';

  @override
  String get payoutAccount => 'الحساب النقدي / حساب الصرف';

  @override
  String get linkedCard => 'بطاقة الائتمان المرتبطة (للبطاقات فقط)';

  @override
  String get cardStatementDay => 'يوم كشف حساب البطاقة';

  @override
  String get cardPaymentDay => 'يوم سداد البطاقة';

  @override
  String get movePrincipalNow => 'نقل أصل المبلغ من النقد أو إليه الآن؟';

  @override
  String get existingPosition => 'لا — هذا مركز قائم';

  @override
  String get recordNewFunding => 'نعم — سجّل تمويلًا جديدًا';

  @override
  String get cardDaysRange => 'يجب أن تكون أيام البطاقة بين 1 و31';

  @override
  String principalAnnual(String amount, String currency, String rate) {
    return '$amount $currency · $rate% سنويًا';
  }

  @override
  String get equalInstallmentsNote =>
      'أقساط متساوية؛ السعر الدوري = السعر السنوي ÷ عدد الدفعات في السنة.';

  @override
  String get flatCouponsNote =>
      'عوائد ثابتة؛ تُحسب الفترة الجزئية الأخيرة بالتناسب مع الأيام الفعلية في الفترة المجدولة.';

  @override
  String outstandingAmount(String amount, String currency) {
    return 'المستحق $amount $currency';
  }

  @override
  String billedLine(String billed, String unbilled, String older, String due) {
    return 'مفوتر $billed · غير مفوتر $unbilled\nأقدم / افتتاحي $older · الاستحقاق $due';
  }

  @override
  String get addAgreedPayment => 'إضافة دفعة متفق عليها';

  @override
  String get earlySettlement => 'تسوية مبكرة';

  @override
  String get outstandingPrincipal => 'أصل المبلغ المستحق';

  @override
  String get agreedFinalInterest => 'الفائدة / الرسوم النهائية المتفق عليها';

  @override
  String get noLinkedCashAccount => 'لا يوجد حساب نقدي مرتبط';

  @override
  String get recordEarlySettlement => 'تسجيل التسوية المبكرة';

  @override
  String principalInterestLine(String principal, String interest) {
    return 'الأصل $principal · الفائدة $interest';
  }

  @override
  String get confirmed => 'مؤكد';

  @override
  String get reverseConfirmedPayment => 'عكس الدفعة المؤكدة';

  @override
  String get reversePaymentTitle => 'عكس الدفعة؟';

  @override
  String get reversePaymentBody =>
      'سيؤدي هذا إلى عكس القيود النقدية المرتبطة ووضع الدفعة كغير مدفوعة.';

  @override
  String get reverse => 'عكس';

  @override
  String confirmActual(String amount, String currency) {
    return 'تأكيد المبلغ الفعلي $amount $currency';
  }

  @override
  String get cashAccountRecordNow => 'الحساب النقدي · سجّل الدفعة الفعلية الآن';

  @override
  String get confirm => 'تأكيد';

  @override
  String get payCreditCard => 'سداد بطاقة الائتمان';

  @override
  String get dueDate => 'تاريخ الاستحقاق';

  @override
  String get principalAmount => 'مبلغ الأصل';

  @override
  String get interestAmount => 'مبلغ الفائدة';

  @override
  String get enterPositivePayment => 'أدخل دفعة موجبة';

  @override
  String get notRecorded => 'غير مسجّل';

  @override
  String get feesForeign => 'رسوم المعاملات الأجنبية';

  @override
  String get feesTransfer => 'رسوم التحويل';

  @override
  String get feesCashAdvance => 'رسوم السحب النقدي';

  @override
  String get feesLate => 'رسوم التأخر في السداد';

  @override
  String get feesAnnual => 'رسوم البطاقات السنوية';

  @override
  String get feesInvestment => 'رسوم الاستثمار';

  @override
  String get feesOther => 'رسوم بنكية أخرى';

  @override
  String percentVsLast(String percent) {
    return '$percent% عن السابق';
  }

  @override
  String priceFxGain(String price, String fx) {
    return 'السعر $price · العملة $fx';
  }

  @override
  String get expenses => 'المصروفات';

  @override
  String get spendingByCategory => 'الإنفاق حسب الفئة';

  @override
  String get noSpendingMonth => 'لا يوجد إنفاق هذا الشهر.';

  @override
  String get totalCaps => 'الإجمالي';

  @override
  String get howYouPaid => 'طريقة الدفع';

  @override
  String get byCardOrWallet => 'حسب البطاقة أو المحفظة';

  @override
  String get spendingByCurrency => 'الإنفاق حسب العملة';

  @override
  String get convertedAtEachDate => 'محوّل إلى عملة التقارير بسعر كل تاريخ.';

  @override
  String get feesInterestPaid => 'الرسوم والفوائد المدفوعة';

  @override
  String get incomeSources => 'مصادر الدخل';

  @override
  String get noIncomeMonth => 'لا يوجد دخل هذا الشهر.';

  @override
  String get assetAllocation => 'توزيع الأصول';

  @override
  String get noValuedAssets => 'لا توجد أصول مُقيَّمة بعد.';

  @override
  String get currencyExposure => 'التعرّض للعملات';

  @override
  String get originalAmounts => 'المبالغ الأصلية قبل التحويل.';

  @override
  String get holdingGains => 'أرباح الأصول منذ البداية';

  @override
  String get holdingGainsNote =>
      'أرباح السعر وأثر سعر الصرف على تكلفة الشراء منفصلان. يبقى سجل الشراء المفقود غير معروف.';

  @override
  String get noGainsYet => 'لا توجد أرباح مسجلة بعد.';

  @override
  String get netWorthHistory => 'سجل صافي الثروة';

  @override
  String get netWorthHistoryNote =>
      'قيم مسجلة فقط. لا تُختلق أي قيم قبل بدء المتابعة.';

  @override
  String get chartAppearsLater =>
      'يظهر الرسم البياني بعد بضعة أيام من المتابعة.';

  @override
  String get expectedCashFlow => 'التدفق النقدي المتوقع · الأيام الـ30 القادمة';

  @override
  String get expectedCashFlowNote =>
      'مبني على جداول عقود غير مؤكدة. هذا توقع وليس نقدًا متاحًا.';

  @override
  String get realizedGains => 'أرباح الاستثمار المحققة';

  @override
  String get noRealizedGains => 'لا توجد أرباح محققة بعد.';

  @override
  String get bankWalletApps => 'تطبيقات البنوك والمحافظ';

  @override
  String get searchApps => 'ابحث في التطبيقات';

  @override
  String get noAppsFound => 'لم يُعثر على تطبيقات.';

  @override
  String get noMatchingApps => 'لا توجد تطبيقات مطابقة.';

  @override
  String get readAlertsTitle => 'قراءة تنبيهات الدفع؟';

  @override
  String get readAlertsBody =>
      'سيقرأ Flourish إشعارات تطبيق الرسائل وتطبيقات البنوك أو المحافظ التي تختارها للعثور على تنبيهات الدفع (المبلغ، التاجر، آخر أرقام البطاقة). تُتجاهل الإشعارات الأخرى فورًا. لا تُحفظ رموز التحقق والمدفوعات المرفوضة أبدًا، وتُختصر أرقام البطاقات إلى آخر 4 أرقام، ولا يغادر أي شيء هاتفك. تراجع كل دفعة قبل إضافتها، إلا إذا فعّلت الإضافة التلقائية.';

  @override
  String get continueAction => 'متابعة';

  @override
  String get detectFromNotifications => 'اكتشاف المدفوعات من الإشعارات';

  @override
  String get detectFromNotificationsSubtitle =>
      'تصل رسائل البنك وتنبيهات تطبيقات البنوك والمحافظ إلى صندوقك';

  @override
  String get accessGranted => 'تم منح صلاحية الإشعارات';

  @override
  String get accessNeeded => 'صلاحية الإشعارات مطلوبة';

  @override
  String get restrictedSettingsHint =>
      'إذا كان المفتاح غير مفعّل، افتح معلومات التطبيق › ⋮ › السماح بالإعدادات المقيدة أولًا.';

  @override
  String get grant => 'منح';

  @override
  String get messagingAlwaysRead =>
      'تُقرأ تطبيقات الرسائل دائمًا. تظهر هنا التطبيقات التي نشرت إشعارات تشبه المعاملات المالية؛ حدّد تطبيقات بنكك أو محفظتك، أو اخترها من التطبيقات المثبتة.';

  @override
  String get noneSeenYet => 'لم يظهر شيء بعد. ستظهر بعد التنبيه التالي.';

  @override
  String alertsCount(int count) {
    return '$count تنبيه';
  }

  @override
  String get chosenFromInstalled => 'مختارة من التطبيقات المثبتة';

  @override
  String get chooseFromInstalled => 'اختر من التطبيقات المثبتة';

  @override
  String get notifyNewPayments => 'أعلمني بالمدفوعات الجديدة';

  @override
  String get iosShortcutsIntro =>
      'لا يسمح iOS للتطبيقات بقراءة الرسائل، لذا يرسلها تطبيق الاختصارات إلى Flourish. أعدّ ذلك مرة واحدة (iOS 17 أو أحدث):';

  @override
  String get iosStep1 => 'افتح الاختصارات › الأتمتة › أتمتة جديدة › الرسالة.';

  @override
  String get iosStep2 =>
      'الرسالة تحتوي على: EGP. اختر التشغيل فورًا. أنشئ أتمتة أخرى لكل كلمة يستخدمها بنكك: جنيه، ج.م، والعملات التي تدفع بها في الخارج أو عبر الإنترنت مثل USD ودولار وEUR وSAR. أضف أتمتة رسالة منفصلة لكلمة LE.';

  @override
  String get iosStep3 =>
      'أضف الإجراء \"Import Transaction Text\" من Flourish ومرّر إليه الرسالة والمرسل.';

  @override
  String get iosStep4 =>
      'لـ Apple Pay: أتمتة جديدة › المحفظة › اختر بطاقاتك › التشغيل فورًا › \"Log Card Payment\" مع المبلغ والتاجر والبطاقة.';

  @override
  String get paymentsArriveInbox =>
      'تصل المدفوعات إلى صندوقك دون فتح Flourish.';

  @override
  String get addingPayments => 'إضافة المدفوعات';

  @override
  String get autoAddClear => 'إضافة المدفوعات الواضحة تلقائيًا';

  @override
  String get autoAddClearSubtitle =>
      'فقط المشتريات والمستردات من بنك معروف، على بطاقة حفظتها بآخر 4 أرقام، دون شك في المبلغ أو احتمال التكرار. كل ما عدا ذلك ينتظرك.';

  @override
  String get aiForUnclear => 'الذكاء الاصطناعي للرسائل غير الواضحة';

  @override
  String aiOnProvider(String provider) {
    return 'مفعّل · $provider';
  }

  @override
  String get aiOffProviders =>
      'متوقف · DeepSeek أو OpenRouter أو Groq أو Gemini';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get keepMessageText => 'الاحتفاظ بنص الرسالة بعد المراجعة';

  @override
  String get dontKeep => 'عدم الاحتفاظ';

  @override
  String daysCount(int count) {
    return '$count يومًا';
  }

  @override
  String get includeTextInBackups => 'تضمين نص الرسائل في النسخ الاحتياطية';

  @override
  String get messageTextDeleted => 'تم حذف نص الرسائل';

  @override
  String get deleteAllMessageText => 'حذف كل نصوص الرسائل الآن';

  @override
  String get testMessage => 'اختبار رسالة';

  @override
  String get pasteAlert => 'الصق تنبيه بنك أو محفظة';

  @override
  String notAPayment(String reason) {
    return 'ليست دفعة ($reason).';
  }

  @override
  String percentSure(int percent) {
    return 'ثقة $percent%';
  }

  @override
  String get kindPurchase => 'شراء';

  @override
  String get kindWithdrawal => 'سحب نقدي';

  @override
  String get kindMoneySent => 'أموال مرسلة';

  @override
  String get kindMoneyReceived => 'أموال مستلمة';

  @override
  String get kindDeposit => 'إيداع';

  @override
  String get kindRefund => 'استرداد';

  @override
  String get kindBillPayment => 'دفع فاتورة';

  @override
  String get kindCardPayment => 'سداد بطاقة';

  @override
  String get kindFee => 'رسوم';

  @override
  String get kindPayment => 'دفعة';

  @override
  String addedPayments(int count) {
    return 'تمت إضافة $count دفعة';
  }

  @override
  String addedWithProblems(int count, int problems, String first) {
    return 'تمت إضافة $count؛ $problems تحتاج إلى مراجعة: $first';
  }

  @override
  String get askingAi => 'جارٍ سؤال الذكاء الاصطناعي…';

  @override
  String get aiNothingToAdd => 'لم يجد الذكاء الاصطناعي ما يضيفه';

  @override
  String updatedPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديث $count دفعة',
      few: 'تم تحديث $count دفعات',
      two: 'تم تحديث دفعتين',
      one: 'تم تحديث دفعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String aiUnavailable(String error) {
    return 'الذكاء الاصطناعي غير متاح: $error';
  }

  @override
  String convertingTo(String currency) {
    return 'جارٍ التحويل إلى $currency…';
  }

  @override
  String noRateYetEdit(String currency) {
    return 'لا يوجد سعر صرف بعد · اضغط تعديل لإدخال المبلغ بـ $currency';
  }

  @override
  String cardFeePercent(String percent) {
    return ' + رسوم بطاقة $percent%';
  }

  @override
  String get rateEstimate => 'تقدير سعر الصرف';

  @override
  String get paymentsToReviewTitle => 'مدفوعات للمراجعة';

  @override
  String get detectionSettings => 'إعدادات الاكتشاف';

  @override
  String get nothingDetected => 'لم يُكتشف شيء بعد';

  @override
  String get nothingDetectedSubtitle =>
      'فعّل اكتشاف المدفوعات لتجميع تنبيهات البنوك والمحافظ هنا، أو الصق تنبيهًا.';

  @override
  String get setUpDetection => 'إعداد الاكتشاف';

  @override
  String checkUnclear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'افحص $count دفعة غير واضحة بالذكاء الاصطناعي',
      few: 'افحص $count دفعات غير واضحة بالذكاء الاصطناعي',
      two: 'افحص الدفعتين غير الواضحتين بالذكاء الاصطناعي',
      one: 'افحص الدفعة غير الواضحة بالذكاء الاصطناعي',
    );
    return '$_temp0';
  }

  @override
  String addReady(int count) {
    return 'إضافة $count دفعة جاهزة';
  }

  @override
  String get allCaughtUp => 'لا شيء متبقٍ.';

  @override
  String get addedAutoThisWeek => 'أضيفت تلقائيًا هذا الأسبوع';

  @override
  String duplicatesDismissed(int count) {
    return 'المكررة والمستبعدة ($count)';
  }

  @override
  String get chooseAnAccount => 'اختر حسابًا';

  @override
  String newProposal(String name) {
    return '✨ جديد: $name';
  }

  @override
  String chargedAmountLine(String currency, String amount) {
    return ' · خُصم $currency $amount';
  }

  @override
  String get maybeEnteredAlready => 'ربما أدخلت هذا مسبقًا';

  @override
  String get sameEntry => 'القيد نفسه';

  @override
  String get sameAsOtherAlert => 'نفس دفعة تنبيه آخر';

  @override
  String get unclearMessage => 'رسالة غير واضحة: تحقّق من التفاصيل';

  @override
  String get askAi => 'اسأل الذكاء الاصطناعي';

  @override
  String get checkedWithAi => 'تم الفحص بالذكاء الاصطناعي';

  @override
  String get showMessage => 'عرض الرسالة';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get reviewAgain => 'مراجعة مجددًا';

  @override
  String bankBalanceDiffers(String balance, String difference) {
    return 'يقول البنك إن رصيدك $balance؛ ويختلف Flourish بمقدار $difference.';
  }

  @override
  String get matchBank => 'مطابقة البنك';

  @override
  String get matchedBankBalance => 'رصيد مطابق لرسالة البنك';

  @override
  String get reviewPayment => 'مراجعة الدفعة';

  @override
  String chargedToAccountPaid(String account, String currency, String amount) {
    return 'مخصوم من الحساب ($account)؛ مدفوع $currency $amount';
  }

  @override
  String chargedInEmpty(String account, String currency, String amount) {
    return 'مخصوم بـ $account (فارغ: سعر الصرف + رسوم البطاقة)؛ مدفوع $currency $amount';
  }

  @override
  String get automatic => 'تلقائي';

  @override
  String get wentToYourAccount => 'هل ذهبت إلى أحد حساباتك؟';

  @override
  String get noSomeoneElse => 'لا، شخص آخر';

  @override
  String get choose => 'اختر';

  @override
  String get cameFromYourAccount => 'هل جاءت من أحد حساباتك؟';

  @override
  String get merchantOrPerson => 'التاجر أو الشخص';

  @override
  String get paymentAdded => 'تمت إضافة الدفعة';

  @override
  String get accountGone => 'الحساب لم يعد موجودًا';

  @override
  String get chooseDifferentCurrencies => 'اختر عملتين مختلفتين';

  @override
  String get chooseDifferentCategories => 'اختر فئتين مختلفتين من النوع نفسه';

  @override
  String get categoryCycle => 'لا يمكن أن يحتوي تسلسل الفئات على حلقة';

  @override
  String get typeRestoreConfirm => 'اكتب RESTORE للتأكيد';

  @override
  String get chooseImportFile =>
      'اختر ملف CSV أو Excel (.xlsx) أو OFX/QFX أو QIF أو كشف PDF';

  @override
  String get fileUnreadable => 'تعذّرت قراءة هذا الملف';

  @override
  String importError(String error) {
    return 'الاستيراد: $error';
  }

  @override
  String get pdfPasswordProtected =>
      'ملف PDF هذا محمي بكلمة مرور. أدخل كلمة المرور لاستيراده.';

  @override
  String get pdfNoText =>
      'لا يحتوي ملف PDF هذا على نص، ويبدو أنه صورة ممسوحة. يحتاج الاستيراد إلى PDF نصي: نزّل الكشف من موقع بنكك أو تطبيقه، أو صدّر CSV أو Excel أو OFX بدلًا منه.';

  @override
  String get pdfNoTable =>
      'لم يُعثر على جدول معاملات في ملف PDF هذا. أعدّ الذكاء الاصطناعي من الإعدادات لقراءة التنسيقات غير المعتادة، أو صدّر CSV أو Excel أو OFX من بنكك.';

  @override
  String get noTransactionsInFile => 'لم يُعثر على معاملات في هذا الملف';

  @override
  String get fileEmpty => 'الملف فارغ';

  @override
  String get invalidHeaderRow => 'رقم صف العناوين غير صالح';

  @override
  String get mapRequiredColumns => 'حدّد أعمدة التاريخ والنوع والحساب والمبلغ';

  @override
  String columnNumber(int n) {
    return 'العمود $n';
  }

  @override
  String get manualOverride => 'تعديل يدوي';

  @override
  String transactionNumber(String id) {
    return 'المعاملة $id';
  }

  @override
  String manageNamed(String name) {
    return 'إدارة $name';
  }

  @override
  String get active => 'نشط';

  @override
  String get include => 'تضمين';

  @override
  String get exclude => 'استبعاد';

  @override
  String get pdfStatementAi => 'كشف PDF (ذكاء اصطناعي)';

  @override
  String readingPage(int page, int total) {
    return 'جارٍ قراءة الصفحة $page من $total…';
  }

  @override
  String readingPart(int part, int total) {
    return 'جارٍ قراءة الجزء $part من $total…';
  }

  @override
  String pdfAiBody(int pages, int requests, String provider) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages صفحة',
      few: '$pages صفحات',
      two: 'صفحتين',
      one: 'صفحة واحدة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      requests,
      locale: localeName,
      other: '$requests طلب',
      few: '$requests طلبات',
      two: 'طلبان',
      one: 'طلب واحد',
    );
    return 'لم يُعثر على جدول يتعرّف عليه Flourish. يُرسل نص $_temp0 ($_temp1) إلى $provider، بعد حذف أرقام الحسابات والبطاقات وأرقام IBAN والهواتف والبريد الإلكتروني وأسطر اسم العميل. تُرسل المبالغ والتواريخ والأوصاف. تُستبعد الصفوف التي لا يظهر مبلغها في الصفحة، وتراجع كل شيء قبل إضافته.';
  }

  @override
  String aiMappingUnavailable(String error) {
    return 'تعيين الأعمدة بالذكاء الاصطناعي غير متاح: $error';
  }

  @override
  String get typedAmounts => 'مبالغ موجبة مع عمود للنوع';

  @override
  String get signedAmounts => 'مبالغ بنكية بإشارة: السالب = مصروف';

  @override
  String get decimalPeriod => 'نقطة (1,234.56)';

  @override
  String get decimalComma => 'فاصلة (1.234,56)';

  @override
  String get accountsTitle => 'الحسابات';

  @override
  String get institution => 'المؤسسة';

  @override
  String get group => 'المجموعة';

  @override
  String get includeInWealth => 'تضمين في إجمالي الثروة';

  @override
  String get owedPerStatement => 'المبلغ المستحق حسب الكشف (اختياري)';

  @override
  String get reconciledBalance => 'الرصيد بعد التسوية (اختياري)';

  @override
  String get reconciliationReason => 'سبب التسوية';

  @override
  String get reconciliationHistory => 'سجل التسويات';

  @override
  String get resumeAutomaticRate => 'العودة للسعر التلقائي';

  @override
  String get manualExchangeRate => 'سعر صرف يدوي';

  @override
  String get oneSourceUnitEquals => 'وحدة واحدة من المصدر تساوي';

  @override
  String get effectiveDate => 'تاريخ السريان';

  @override
  String get addOverride => 'إضافة تعديل';

  @override
  String get transactionTemplates => 'قوالب المعاملات';

  @override
  String get newTemplate => 'قالب جديد';

  @override
  String get saveTemplate => 'حفظ القالب';

  @override
  String get reviewTemplateTx => 'مراجعة معاملة القالب';

  @override
  String get templateName => 'اسم القالب';

  @override
  String get amountInAccountCurrency => 'المبلغ بعملة الحساب';

  @override
  String get recordTransaction => 'تسجيل المعاملة';

  @override
  String get assignSubcategory => 'تعيين فئة فرعية';

  @override
  String get childCategory => 'الفئة الفرعية';

  @override
  String get parentCategory => 'الفئة الأم';

  @override
  String get noParent => 'بدون فئة أم';

  @override
  String get receipts => 'الإيصالات';

  @override
  String get attachReceipt => 'إرفاق إيصال';

  @override
  String get encryptedBackup => 'نسخة احتياطية مشفّرة';

  @override
  String get passwordMin10 => 'كلمة المرور (10 أحرف أو أكثر)';

  @override
  String get export => 'تصدير';

  @override
  String get replaceFromBackup =>
      'استبدال البيانات الحالية من النسخة الاحتياطية';

  @override
  String get backupPassword => 'كلمة مرور النسخة الاحتياطية';

  @override
  String get typeRestoreReplaceAll =>
      'اكتب RESTORE لاستبدال كل البيانات الحالية';

  @override
  String get restore => 'استعادة';

  @override
  String get localBackupHistory => 'سجل النسخ الاحتياطية المحلية';

  @override
  String get restoreLocalBackup => 'استعادة هذه النسخة المحلية';

  @override
  String get typeRestoreReplace => 'اكتب RESTORE لاستبدال البيانات الحالية';

  @override
  String get chooseWorksheet => 'اختر ورقة العمل';

  @override
  String get worksheet => 'ورقة العمل';

  @override
  String get pdfStatement => 'كشف PDF';

  @override
  String get readStatementAi => 'قراءة هذا الكشف بالذكاء الاصطناعي؟';

  @override
  String get useAi => 'استخدام الذكاء الاصطناعي';

  @override
  String get aiNoTransactionsPdf =>
      'لم يجد الذكاء الاصطناعي معاملات في ملف PDF هذا';

  @override
  String get pdfPassword => 'كلمة مرور PDF';

  @override
  String get password => 'كلمة المرور';

  @override
  String get pdfPasswordHint => 'تستخدم البنوك غالبًا رقمك القومي أو رقم حسابك';

  @override
  String get open => 'فتح';

  @override
  String get whichHeaderRow => 'أي صف يحتوي على أسماء الأعمدة؟';

  @override
  String get headerRowNumber => 'رقم صف العناوين';

  @override
  String get mapColumnsAiTitle => 'تعيين الأعمدة بالذكاء الاصطناعي؟';

  @override
  String get mapColumnsAiBody =>
      'يرسل أسماء الأعمدة و5 صفوف مع إخفاء أرقام الحسابات والهواتف والبريد الإلكتروني. يمكنك تغيير كل اختيار لاحقًا.';

  @override
  String get mapMyself => 'سأعيّنها بنفسي';

  @override
  String get mapColumns => 'تعيين الأعمدة';

  @override
  String get mapColumnsAi => 'تعيين الأعمدة (اقتراح الذكاء الاصطناعي)';

  @override
  String get notMapped => 'غير معيّن';

  @override
  String get amountConvention => 'طريقة كتابة المبالغ';

  @override
  String get decimalSeparator => 'الفاصل العشري';

  @override
  String get dateFormatNonIso => 'تنسيق التاريخ للتواريخ غير القياسية';

  @override
  String get review => 'مراجعة';

  @override
  String get spreadsheet => 'جدول بيانات';

  @override
  String get amountEnter => 'أدخل مبلغًا';

  @override
  String get amountCheckFormat => 'تحقّق من تنسيق الرقم';

  @override
  String get amountNumbersOnly => 'أدخل أرقامًا فقط';

  @override
  String amountNoDecimals(String currency) {
    return 'لا تحتوي $currency على كسور عشرية';
  }

  @override
  String amountMaxDecimals(int digits, String currency) {
    return 'استخدم $digits منازل عشرية كحد أقصى لـ $currency';
  }

  @override
  String get amountAboveZero => 'أدخل مبلغًا أكبر من صفر';

  @override
  String get methodCash => 'نقدًا';

  @override
  String get methodDebitCard => 'بطاقة خصم';

  @override
  String get methodCreditCard => 'بطاقة ائتمان';

  @override
  String get methodPrepaidCard => 'بطاقة مسبقة الدفع';

  @override
  String get methodMobileWallet => 'محفظة إلكترونية';

  @override
  String get methodInstaPay => 'إنستاباي';

  @override
  String get methodBankTransfer => 'تحويل بنكي';

  @override
  String get methodBnpl => 'تقسيط (اشترِ الآن وادفع لاحقًا)';

  @override
  String get methodCard => 'بطاقة';

  @override
  String get intlLimit => 'الحد الدولي';

  @override
  String intlLimitIn(String currency) {
    return 'الحد الدولي ($currency)';
  }

  @override
  String get intlLimitOptional => 'الحد الدولي (اختياري)';

  @override
  String get availableAbroad => 'المتاح دوليًا';

  @override
  String overIntlLimitBy(String amount) {
    return 'تجاوز الحد الدولي بمقدار $amount';
  }

  @override
  String overCardIntlLimit(String amount) {
    return 'يتجاوز هذا الحد الدولي للبطاقة بمقدار $amount.';
  }

  @override
  String bankSaidAvailable(String date, String amount) {
    return 'رسالة البنك بتاريخ $date: المتاح $amount';
  }

  @override
  String bankSaidIntlAvailable(String date, String amount) {
    return 'رسالة البنك بتاريخ $date: المتاح دوليًا $amount';
  }

  @override
  String bankLimitDiffers(String available, String difference) {
    return 'يقول البنك إن المتاح على هذه البطاقة $available؛ ويختلف Flourish بمقدار $difference.';
  }

  @override
  String get matchedBankLimit => 'حد متاح مطابق لرسالة البنك';

  @override
  String get catSalary => 'الراتب';

  @override
  String get catFreelance => 'العمل الحر';

  @override
  String get catInvestment => 'الاستثمار';

  @override
  String get catFood => 'الطعام والمشروبات';

  @override
  String get catTransport => 'المواصلات';

  @override
  String get catShopping => 'التسوق';

  @override
  String get catBills => 'الفواتير والمرافق';

  @override
  String get catEntertainment => 'الترفيه';

  @override
  String get catHealth => 'الصحة';

  @override
  String get catEducation => 'التعليم';

  @override
  String get catHousing => 'السكن';

  @override
  String get catTransferOut => 'تحويل صادر';

  @override
  String get catTransferIn => 'تحويل وارد';

  @override
  String get catInvestmentPurchases => 'مشتريات استثمارية';

  @override
  String get catInvestmentSales => 'مبيعات استثمارية';

  @override
  String get catPrincipalPaid => 'أصل دين مدفوع';

  @override
  String get catPrincipalReceived => 'أصل دين مستلم';

  @override
  String get catBankFees => 'رسوم بنكية';

  @override
  String get catInterestCharges => 'الفوائد والرسوم';

  @override
  String get catInterestEarned => 'فوائد مكتسبة';

  @override
  String get catchUpTitle => 'مراجعة آخر 7 أيام';

  @override
  String get catchUpSubtitle =>
      'اعثر على مدفوعات الأسبوع الماضي غير المسجلة في Flourish';

  @override
  String get catchUpIntro =>
      'لا يسمح iPhone للتطبيقات بقراءة الرسائل، لذا أحضر مدفوعات الأسبوع الماضي بإحدى طريقتين. يقارنها Flourish بما سجّلته بالفعل ويسألك فقط عن الناقص.';

  @override
  String get catchUpPasteTitle => 'الصق رسائل البنك';

  @override
  String get catchUpPasteBody =>
      'في تطبيق الرسائل انسخ كل رسالة من آخر 7 أيام والصقها هنا واحدة تلو الأخرى.';

  @override
  String get catchUpPasteHint => 'الصق الرسائل هنا';

  @override
  String get catchUpCheck => 'افحص';

  @override
  String get catchUpStatementTitle => 'استيراد كشف حساب';

  @override
  String get catchUpStatementBody =>
      'نزّل كشف حساب من تطبيق البنك (PDF أو CSV أو OFX أو QIF). تتم مقارنة آخر 7 أيام فقط.';

  @override
  String get catchUpChooseFile => 'اختر ملفًا';

  @override
  String catchUpMissingHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مدفوعة غير مسجلة في Flourish',
      many: '$count مدفوعة غير مسجلة في Flourish',
      few: '$count مدفوعات غير مسجلة في Flourish',
      two: 'مدفوعتان غير مسجلتين في Flourish',
      one: 'مدفوعة واحدة غير مسجلة في Flourish',
      zero: 'لا شيء ناقص',
    );
    return '$_temp0';
  }

  @override
  String get catchUpAllCaughtUp =>
      'كل شيء محدّث: جميع مدفوعات آخر 7 أيام مسجلة بالفعل في Flourish.';

  @override
  String catchUpAlreadyHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسجلة بالفعل',
      many: '$count مسجلة بالفعل',
      few: '$count مسجلة بالفعل',
      two: 'اثنتان مسجلتان بالفعل',
      one: 'واحدة مسجلة بالفعل',
    );
    return '$_temp0';
  }

  @override
  String get catchUpMarkRecorded => 'اعتبرها مضافة بالفعل';

  @override
  String catchUpOlder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أقدم من 7 أيام',
      many: '$count أقدم من 7 أيام',
      few: '$count أقدم من 7 أيام',
      two: 'اثنتان أقدم من 7 أيام',
      one: 'واحدة أقدم من 7 أيام',
    );
    return '$_temp0';
  }

  @override
  String catchUpIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رمز أو عرض أو تنبيه',
      many: '$count رمزًا أو عرضًا أو تنبيهًا',
      few: '$count رموز أو عروض أو تنبيهات',
      two: 'رمزان أو عروض أو تنبيهات',
      one: 'رمز أو عرض أو تنبيه واحد',
    );
    return '$_temp0';
  }

  @override
  String catchUpRepeated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مستلمة من قبل',
      many: '$count مستلمة من قبل',
      few: '$count مستلمة من قبل',
      two: 'اثنتان مستلمتان من قبل',
      one: 'واحدة مستلمة من قبل',
    );
    return '$_temp0';
  }

  @override
  String get catchUpAdd => 'أضف';

  @override
  String get catchUpSkip => 'تخطَّ';

  @override
  String get catchUpAdded => 'تمت الإضافة';

  @override
  String get catchUpSkipped => 'تم التخطي';

  @override
  String catchUpAddAll(int count) {
    return 'أضف الكل ($count)';
  }

  @override
  String catchUpOlderLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم استبعاد $count صف أقدم من 7 أيام',
      many: 'تم استبعاد $count صفًا أقدم من 7 أيام',
      few: 'تم استبعاد $count صفوف أقدم من 7 أيام',
      two: 'تم استبعاد صفين أقدم من 7 أيام',
      one: 'تم استبعاد صف واحد أقدم من 7 أيام',
    );
    return '$_temp0';
  }

  @override
  String get catchUpReviewTitle => 'المدفوعات الناقصة';

  @override
  String get catchUpChooseAccount => 'اختر الحساب أولًا';

  @override
  String get catchUpAlreadyTitle => 'مسجلة بالفعل في Flourish';

  @override
  String get iosGuideTitle => 'الاكتشاف التلقائي على iPhone';

  @override
  String get iosGuideSubtitle =>
      'اضبط الاختصارات لتصل رسائل البنك الجديدة إلى Flourish تلقائيًا';

  @override
  String get iosGuideIntro =>
      'لا يسمح iPhone للتطبيقات بقراءة الرسائل أو الإشعارات. تقوم أتمتة في تطبيق الاختصارات بتمرير كل رسالة جديدة إلى Flourish في الخلفية. اضبطها مرة واحدة، وتستغرق دقيقتين تقريبًا.';

  @override
  String get iosGuideMessagesTitle => '1. رسائل البنك (الرسائل)';

  @override
  String get iosGuideMsg1 => 'افتح تطبيق الاختصارات، واضغط الأتمتة ثم +.';

  @override
  String get iosGuideMsg2 =>
      'اختر رسالة. في «تحتوي الرسالة على» اكتب EGP (ويمكنك أيضًا اختيار البنك في «المرسل»). أضف أتمتة رسالة منفصلة تحتوي على LE. يجب تحديث الأتمتة الحالية يدويًا.';

  @override
  String get iosGuideMsg3 => 'اختر «تشغيل فورًا» ثم «التالي».';

  @override
  String get iosGuideMsg4 =>
      'اضغط «أتمتة فارغة جديدة» ثم «إضافة إجراء» وابحث عن Flourish.';

  @override
  String get iosGuideMsg5 =>
      'اختر Import Transaction Text. اجعل Transaction Text = مُدخل الاختصار › المحتوى، وSender = مُدخل الاختصار › المرسل.';

  @override
  String get iosGuideMsg6 =>
      'اضغط «تم». كرّر ذلك لكلمات جنيه وج.م وأي عملة أخرى يكتبها البنك (USD، دولار…).';

  @override
  String get iosGuideWalletTitle => '2. Apple Pay (المحفظة)';

  @override
  String get iosGuideWallet1 =>
      'في الاختصارات › الأتمتة اضغط +، واختر «معاملة» ثم بطاقاتك.';

  @override
  String get iosGuideWallet2 => 'اختر «تشغيل فورًا» ثم «أتمتة فارغة جديدة».';

  @override
  String get iosGuideWallet3 =>
      'أضف Flourish › Log Card Payment واجعل Amount وMerchant وCard من مُدخل الاختصار.';

  @override
  String get iosGuideWallet4 =>
      'اضغط «تم». ستظهر كل مدفوعة Apple Pay الآن في «مدفوعات للمراجعة».';

  @override
  String get iosGuideCheckTitle => '3. تأكد أنها تعمل';

  @override
  String get iosGuideCheck =>
      'انتظر رسالة البنك التالية، أو أرسل لنفسك رسالة تجريبية مثل «Purchase of EGP 10.00 at Test». سيُظهر Flourish إشعارًا وتنتظر المدفوعة في «مدفوعات للمراجعة».';

  @override
  String get iosGuideOpenShortcuts => 'افتح الاختصارات';

  @override
  String get iosGuideCatchUpHint =>
      'فاتتك بعض الأيام؟ «مراجعة آخر 7 أيام» تُحضر مدفوعات الأسبوع الماضي.';

  @override
  String get useTemplate => 'استخدام قالب';

  @override
  String get noTemplates =>
      'لا توجد قوالب بعد. أنشئ قالبًا من الأدوات ← قوالب المعاملات.';

  @override
  String get chooseTemplateAmount => 'اختر مبلغًا';

  @override
  String get templateCategoryMismatch => 'اختر فئة تتوافق مع نوع المعاملة';

  @override
  String get templatePositiveAmounts => 'أدخل من مبلغ واحد إلى ٣ مبالغ موجبة';

  @override
  String get homeScreenWidgets => 'أدوات الشاشة الرئيسية';

  @override
  String get widgetSetup =>
      'على أندرويد اضغط مطولًا على الشاشة الرئيسية ← الأدوات ← Flourish. على آيفون اضغط مطولًا ← تعديل ← إضافة أداة ← Flourish. اختر الملخص الشهري أو الإضافة السريعة. تُخفى المبالغ عند تفعيل قفل التطبيق أو إخفاء المبالغ. افتح التطبيق لتحديث الملخص.';

  @override
  String get widgetMonthlySummary => 'الملخص الشهري';

  @override
  String get widgetQuickAdd => 'إضافة سريعة';

  @override
  String get widgetOpenToRefresh => 'افتح Flourish للتحديث';

  @override
  String get widgetUpdated => 'آخر تحديث';

  @override
  String get toolsSubtitle => 'القوالب والاستيراد والنسخ الاحتياطي والأمان';

  @override
  String get globalSearch => 'ابحث في التطبيق';

  @override
  String get searchEverythingHint => 'معاملات، تجار، أدوات…';

  @override
  String get searchIndexing => 'جارٍ تجهيز فهرس البحث…';

  @override
  String get searchFailed => 'تعذر البحث. حاول مرة أخرى.';

  @override
  String get searchFeatures => 'مزايا التطبيق';

  @override
  String get searchObligations => 'الالتزامات';

  @override
  String get searchFilters => 'مرشحات المعاملات';

  @override
  String get minimumAmount => 'الحد الأدنى للمبلغ';

  @override
  String get maximumAmount => 'الحد الأقصى للمبلغ';

  @override
  String get searchRelevance => 'الأكثر صلة';

  @override
  String get searchNewest => 'الأحدث أولاً';

  @override
  String get loadMoreResults => 'المزيد من النتائج';

  @override
  String get currencyConverter => 'محول العملات';

  @override
  String get referenceRate => 'سعر المزود المرجعي';

  @override
  String get effectiveRate => 'السعر الفعلي المستخدم';

  @override
  String get rateUnavailable => 'لا يتوفر سعر لهذا الزوج.';

  @override
  String get cachedRateNotice => 'سعر مرجعي يومي محفوظ. اسحب للتحديث.';

  @override
  String get rateRefreshFailed =>
      'تعذر التحديث. تم الاحتفاظ بالأسعار المحفوظة.';

  @override
  String get rateStale => 'آخر تحديث منذ أكثر من ٢٤ ساعة';

  @override
  String get favoritePairs => 'أزواج العملات المفضلة';

  @override
  String get searchCurrency => 'البحث عن العملات';

  @override
  String get rateAsOf => 'تاريخ السعر';

  @override
  String get rateFetched => 'آخر جلب';

  @override
  String get searchMissingRecord => 'لم يعد هذا السجل موجوداً.';

  @override
  String get searchStart => 'ابحث في السجلات ومزايا التطبيق';

  @override
  String get searchAmountCurrency =>
      'مرشحات المبلغ تستخدم العملة المحددة دون تحويل.';

  @override
  String get clearFilters => 'مسح المرشحات';

  @override
  String get searchRetry => 'إعادة المحاولة';

  @override
  String get searchClear => 'مسح';

  @override
  String get searchApply => 'تطبيق';
}
