import '../../domain/finance/amount.dart';
import '../utils/text_normalizer.dart';

abstract final class SearchText {
  static final replacements = <String, String>{
    for (var i = 0; i < 10; i++) ...{
      String.fromCharCode(0x660 + i): '$i',
      String.fromCharCode(0x6f0 + i): '$i',
    },
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ى': 'ي',
    'ة': 'ه',
    'ـ': '',
    for (var i = 0x64b; i <= 0x65f; i++) String.fromCharCode(i): '',
    'ٰ': '',
  };
  static String normalize(String text) {
    var value = TextNormalizer.digits(text).toLowerCase();
    for (final e in replacements.entries) {
      value = value.replaceAll(e.key, e.value);
    }
    return value.trim();
  }

  static String sql(String expression) {
    var value = 'lower(coalesce($expression,\'\'))';
    for (final e in replacements.entries) {
      value = "replace($value,'${e.key}','${e.value}')";
    }
    // Keep expression nesting below SQLite's parser stack limit.
    return value;
  }

  static String? match(String text, {required bool fragments}) {
    final words = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(normalize(text)).map((m) => m.group(0)!).toList();
    if (words.isEmpty) return null;
    return words
        .map((w) => '"${w.replaceAll('"', '""')}"${fragments ? '' : '*'}')
        .join(' AND ');
  }
}

class SearchFilters {
  final String? kind, transactionType, currency;
  final int? accountId;
  final DateTime? from, to;
  final Amount? minimum, maximum;
  final bool newest;
  const SearchFilters({
    this.kind,
    this.transactionType,
    this.currency,
    this.accountId,
    this.from,
    this.to,
    this.minimum,
    this.maximum,
    this.newest = false,
  });
}

class SearchQuery {
  final String text;
  final SearchFilters filters;
  const SearchQuery(this.text, {this.filters = const SearchFilters()});
}

class SearchCursor {
  final int rank, date, rowid;
  const SearchCursor(this.rank, this.date, this.rowid);
}

class SearchHit {
  final String kind, id, title, subtitle, currency, amount, target;
  final int rowid, rank, date;
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.currency,
    required this.amount,
    required this.target,
    required this.rowid,
    required this.rank,
    required this.date,
  });
}

class SearchPage {
  final List<SearchHit> hits;
  final SearchCursor? next;
  const SearchPage(this.hits, this.next);
}

/// Lexicographically sortable, positive exact decimal; never coerces to REAL.
String amountSearchKey(Amount amount) {
  if (amount < Amount.zero) throw ArgumentError('Amount must be positive');
  final parts = amount.toString().split('.');
  return '${parts.first.length.toString().padLeft(8, '0')}:${parts.first}.${parts.length == 1 ? '' : parts.last}';
}
