import 'package:intl/intl.dart';

/// Helper: convert date to a daily key like "2025-11-24"
String dateKeyFromDate(DateTime date) {
  final onlyDate = DateTime(date.year, date.month, date.day);
  return DateFormat('yyyy-MM-dd').format(onlyDate);
}
