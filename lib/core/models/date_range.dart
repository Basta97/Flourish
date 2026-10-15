import 'package:flutter/material.dart';

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange &&
        other.start.millisecondsSinceEpoch == start.millisecondsSinceEpoch &&
        other.end.millisecondsSinceEpoch == end.millisecondsSinceEpoch;
  }

  @override
  int get hashCode =>
      Object.hash(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);

  DateTimeRange toFlutter() => DateTimeRange(start: start, end: end);
}
