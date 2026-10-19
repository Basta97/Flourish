import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../core/search/search_models.dart';

/// Derived data only. Source tables and ledger records remain authoritative.
abstract final class SearchIndex {
  static const features = <(String, String, String)>[
    ('Tools · الأدوات', 'tools utilities ادوات', '/tools'),
    ('Templates · القوالب', 'transaction templates قالب قوالب', '/templates'),
    (
      'Exchange rates · أسعار الصرف',
      'currency converter تحويل العملات سعر صرف',
      '/exchange-rates',
    ),
    (
      'Backup · النسخ الاحتياطي',
      'backup restore export استعادة تصدير نسخ احتياطي',
      '/settings?section=data',
    ),
    (
      'Security · الأمان',
      'authentication biometric privacy قفل بصمة خصوصية',
      '/tools',
    ),
    ('Settings · الإعدادات', 'settings اعدادات', '/settings'),
    ('Reports · التقارير', 'wealth reports ثروة تقارير', '/wealth?tab=reports'),
    (
      'Payment detection · اكتشاف المدفوعات',
      'notifications sms كشف الدفع اشعارات',
      '/settings/detection',
    ),
    ('Review inbox · مراجعة المدفوعات', 'inbox review وارد مراجعة', '/inbox'),
    (
      'Home widgets · أدوات الشاشة الرئيسية',
      'widgets home screen ويدجت شاشة رئيسية',
      '/tools',
    ),
    (
      'Recurring · المعاملات المتكررة',
      'recurring scheduled متكرر جدولة',
      '/recurring',
    ),
    (
      'Payment methods · طرق الدفع',
      'cards wallets بطاقات محافظ',
      '/payment-methods',
    ),
  ];
  static const aliases = <String, String>{
    'Salary': 'راتب مرتب',
    'Freelance': 'عمل حر',
    'Investment': 'استثمار',
    'Food & Drinks': 'طعام مشروبات اكل',
    'Transport': 'مواصلات نقل',
    'Shopping': 'تسوق',
    'Bills & Utilities': 'فواتير مرافق',
    'Entertainment': 'ترفيه',
    'Health': 'صحة',
    'Education': 'تعليم',
    'Housing': 'سكن',
    'Other': 'اخرى',
    'Other income': 'دخل اخر',
    'Transfer Out': 'تحويل صادر',
    'Transfer In': 'تحويل وارد',
    'Bank fees': 'رسوم بنكية',
    'Investment purchases': 'مشتريات استثمار',
    'Investment sales': 'مبيعات استثمار',
    'Principal paid': 'اصل مدفوع',
    'Principal received': 'اصل مستلم',
    'Investment fees': 'رسوم استثمار',
    'Interest & charges': 'فوائد رسوم',
    'Interest earned': 'فوائد مكتسبة',
  };
  static String _categoryAliases(String name) =>
      "CASE $name ${aliases.entries.map((e) => "WHEN '${e.key.replaceAll("'", "''")}' THEN '${e.value}'").join(' ')} ELSE '' END";

  static Map<String, String> get projections => {
    'transactions': """SELECT 'transaction' kind, CAST(t.id AS TEXT) record_id,
      coalesce(nullif(t.merchant,''),nullif(t.note,''),t.type) title,
      coalesce(t.note,'') || ' ' || coalesce(t.merchant,'') || ' ' || coalesce(json_extract(td.payload,'\$.currency'),'') || ' ' || t.type || ' ' ||
      CASE WHEN t.linked_transaction_id IS NOT NULL THEN 'transfer تحويل' WHEN t.type='income' THEN 'دخل' ELSE 'مصروف' END body,
      t.account_id account_id,t.category_id category_id,
      CASE WHEN t.linked_transaction_id IS NOT NULL THEN 'transfer' ELSE t.type END tx_type,
      t.transaction_date date, CAST(t.amount AS TEXT) amount,'' currency,'' target,t.rowid source_rowid FROM transactions t LEFT JOIN transaction_details td ON td.transaction_id=t.id""",
    'accounts':
        "SELECT 'account' kind,CAST(id AS TEXT) record_id,name title,type || ' ' || currency body,id account_id,NULL category_id,'' tx_type,created_at date,'' amount,currency,'/accounts/' || id target,rowid source_rowid FROM accounts",
    'categories':
        "SELECT 'category' kind,CAST(id AS TEXT) record_id,name title,type || ' ' || ${_categoryAliases('name')} body,NULL account_id,id category_id,'' tx_type,0 date,'' amount,'' currency,'/categories/manage' target,rowid source_rowid FROM categories",
    'goals':
        "SELECT 'goal' kind,CAST(id AS TEXT) record_id,name title,'' body,account_id,NULL category_id,'' tx_type,deadline date,CAST(target_amount AS TEXT) amount,'' currency,'/goals' target,rowid source_rowid FROM goals",
    'budgets':
        "SELECT 'budget' kind,CAST(id AS TEXT) record_id,period title,'budget ميزانية' body,NULL account_id,category_id,'' tx_type,start_date date,CAST(amount AS TEXT) amount,'' currency,'/budgets' target,rowid source_rowid FROM budgets",
    'finance_records':
        """SELECT CASE collection WHEN 'templates' THEN 'template' WHEN 'holdings' THEN 'holding' ELSE 'obligation' END kind,id record_id,
      coalesce(json_extract(payload,'\$.name'),'') title,
      coalesce(json_extract(payload,'\$.note'),'') || ' ' || coalesce(json_extract(payload,'\$.symbol'),'') || ' ' || coalesce(json_extract(payload,'\$.counterparty'),'') || ' ' || coalesce(json_extract(payload,'\$.currency'),'') body,
      CAST(coalesce(json_extract(payload,'\$.account'),json_extract(payload,'\$.accountId')) AS INTEGER) account_id,
      CAST(json_extract(payload,'\$.category') AS INTEGER) category_id,'' tx_type,0 date,'' amount,
      coalesce(json_extract(payload,'\$.currency'),'') currency,'' target,rowid source_rowid
      FROM finance_records WHERE collection IN ('templates','holdings','contracts')""",
  };

  static String _insert(String projection) =>
      '''INSERT INTO search_documents
    (kind,record_id,title,body,title_norm,text_norm,account_id,category_id,tx_type,date,amount,currency,target)
    SELECT kind,record_id,title,body,${SearchText.sql('title')},${SearchText.sql("title || ' | ' || body")},account_id,category_id,tx_type,date,amount,currency,target FROM ($projection) WHERE true
    ON CONFLICT(kind,record_id) DO UPDATE SET title=excluded.title,body=excluded.body,title_norm=excluded.title_norm,text_norm=excluded.text_norm,account_id=excluded.account_id,category_id=excluded.category_id,tx_type=excluded.tx_type,date=excluded.date,amount=excluded.amount,currency=excluded.currency,target=excluded.target
    WHERE search_documents.title IS NOT excluded.title OR search_documents.body IS NOT excluded.body OR search_documents.account_id IS NOT excluded.account_id OR search_documents.category_id IS NOT excluded.category_id OR search_documents.tx_type IS NOT excluded.tx_type OR search_documents.date IS NOT excluded.date OR search_documents.amount IS NOT excluded.amount OR search_documents.currency IS NOT excluded.currency OR search_documents.target IS NOT excluded.target''';

  static Future<void> create(AppDatabase db) async {
    for (final sql in [
      '''CREATE TABLE IF NOT EXISTS search_documents (
      rowid INTEGER PRIMARY KEY,kind TEXT NOT NULL,record_id TEXT NOT NULL,title TEXT NOT NULL,body TEXT NOT NULL,
      title_norm TEXT NOT NULL,text_norm TEXT NOT NULL,account_id INTEGER,category_id INTEGER,tx_type TEXT NOT NULL,date INTEGER NOT NULL,amount TEXT NOT NULL,currency TEXT NOT NULL,target TEXT NOT NULL,UNIQUE(kind,record_id))''',
      "CREATE VIRTUAL TABLE IF NOT EXISTS search_words USING fts5(text_norm,content='search_documents',content_rowid='rowid',tokenize='unicode61',prefix='1 2 3')",
      "CREATE VIRTUAL TABLE IF NOT EXISTS search_fragments USING fts5(text_norm,content='search_documents',content_rowid='rowid',tokenize='trigram')",
      'CREATE TABLE IF NOT EXISTS search_progress (source TEXT PRIMARY KEY,checkpoint INTEGER NOT NULL,complete INTEGER NOT NULL DEFAULT 0)',
      'CREATE INDEX IF NOT EXISTS search_kind ON search_documents(kind,date,rowid)',
      'CREATE INDEX IF NOT EXISTS search_account ON search_documents(account_id,kind)',
      'CREATE INDEX IF NOT EXISTS search_category ON search_documents(category_id,kind)',
    ]) {
      await db.customStatement(sql);
    }
    for (final index in ['search_words', 'search_fragments']) {
      await db.customStatement(
        "CREATE TRIGGER IF NOT EXISTS ${index}_insert AFTER INSERT ON search_documents BEGIN INSERT INTO $index(rowid,text_norm) VALUES(new.rowid,new.text_norm); END",
      );
      await db.customStatement(
        "CREATE TRIGGER IF NOT EXISTS ${index}_delete AFTER DELETE ON search_documents BEGIN INSERT INTO $index($index,rowid,text_norm) VALUES('delete',old.rowid,old.text_norm); END",
      );
      await db.customStatement(
        "CREATE TRIGGER IF NOT EXISTS ${index}_update AFTER UPDATE ON search_documents BEGIN INSERT INTO $index($index,rowid,text_norm) VALUES('delete',old.rowid,old.text_norm); INSERT INTO $index(rowid,text_norm) VALUES(new.rowid,new.text_norm); END",
      );
    }
    for (final e in projections.entries) {
      final source = e.key;
      final kind = source == 'finance_records'
          ? "CASE old.collection WHEN 'templates' THEN 'template' WHEN 'holdings' THEN 'holding' ELSE 'obligation' END"
          : "'${{'transactions': 'transaction', 'accounts': 'account', 'categories': 'category', 'goals': 'goal', 'budgets': 'budget'}[source]}'";
      final condition = source == 'finance_records'
          ? " AND old.collection IN ('templates','holdings','contracts')"
          : '';
      final remove =
          'DELETE FROM search_documents WHERE kind=$kind AND record_id=old.id$condition;';
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final project =
            "SELECT * FROM (${e.value}) WHERE source_rowid=new.rowid";
        await db.customStatement(
          'CREATE TRIGGER IF NOT EXISTS search_${source}_${event.toLowerCase()} AFTER ${event == 'UPDATE' && source == 'accounts' ? 'UPDATE OF name,type,currency' : event} ON $source BEGIN ${event != 'INSERT' ? remove : ''} ${event != 'DELETE' ? '${_insert(project)};' : ''} END',
        );
      }
      await db.customStatement(
        'INSERT OR IGNORE INTO search_progress(source,checkpoint) VALUES (?,0)',
        [source],
      );
    }
    for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
      final id = event == 'DELETE'
          ? 'old.transaction_id'
          : 'new.transaction_id';
      await db.customStatement(
        'CREATE TRIGGER IF NOT EXISTS search_details_${event.toLowerCase()} AFTER $event ON transaction_details BEGIN ${_insert('SELECT * FROM (${projections['transactions']}) WHERE record_id=CAST($id AS TEXT)')}; END',
      );
    }
    for (var i = 0; i < features.length; i++) {
      final f = features[i];
      await db.customStatement(
        'INSERT OR IGNORE INTO search_documents(kind,record_id,title,body,title_norm,text_norm,tx_type,date,amount,currency,target) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        [
          'feature',
          '$i',
          f.$1,
          f.$2,
          SearchText.normalize(f.$1),
          SearchText.normalize('${f.$1} ${f.$2}'),
          '',
          0,
          '',
          '',
          f.$3,
        ],
      );
    }
  }

  static Future<bool> complete(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM search_progress WHERE complete=0 LIMIT 1',
              )
              .get())
          .isEmpty;
  static Future<void> backfill(AppDatabase db) async {
    for (final e in projections.entries) {
      while (true) {
        final state = await db
            .customSelect(
              'SELECT checkpoint,complete FROM search_progress WHERE source=?',
              variables: [Variable(e.key)],
            )
            .getSingle();
        if (state.read<int>('complete') == 1) break;
        final last = state.read<int>('checkpoint');
        final rows = await db
            .customSelect(
              'SELECT rowid AS source_id FROM ${e.key} WHERE rowid>? ORDER BY rowid LIMIT 500',
              variables: [Variable(last)],
            )
            .get();
        if (rows.isEmpty) {
          await db.customStatement(
            'UPDATE search_progress SET complete=1 WHERE source=?',
            [e.key],
          );
          break;
        }
        final end = rows.last.read<int>('source_id');
        await db.transaction(() async {
          await db.customStatement(
            _insert(
              'SELECT * FROM (${e.value}) WHERE source_rowid>$last AND source_rowid<=$end',
            ),
          );
          await db.customStatement(
            'UPDATE search_progress SET checkpoint=? WHERE source=?',
            [end, e.key],
          );
        });
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  static Future<void> rebuild(AppDatabase db) async {
    await db.customStatement(
      'DELETE FROM search_documents WHERE kind<>\'feature\'',
    );
    await db.customStatement(
      'UPDATE search_progress SET checkpoint=0,complete=0',
    );
    await backfill(db);
  }
}
