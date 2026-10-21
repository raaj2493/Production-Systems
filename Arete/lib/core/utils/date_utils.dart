import 'package:intl/intl.dart';

class AppDateUtils {
  /// Returns date formatted as 'YYYY-MM-DD'
  static String toIsoDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Parses date from 'YYYY-MM-DD'
  static DateTime parseIsoDate(String dateStr) {
    return DateTime.parse(dateStr);
  }

  /// Format: "Monday, October 19"
  static String formatHeaderDate(DateTime date) {
    return DateFormat('EEEE, MMMM d').format(date);
  }

  /// Format: "Oct 19" or "Oct 19, 2026"
  static String formatShortDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    }
    return DateFormat('MMM d, y').format(date);
  }

  /// Format: "Oct 19, 10:30 AM"
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }

  /// Returns true if two dates represent the same calendar day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Returns today's date formatted as YYYY-MM-DD
  static String get todayIso => toIsoDate(DateTime.now());

  /// Returns a list of the last [days] dates ending on [endDate] (defaults to today)
  static List<DateTime> getDaysRange(int days, {DateTime? endDate}) {
    final end = endDate ?? DateTime.now();
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    return List.generate(days, (i) {
      return normalizedEnd.subtract(Duration(days: days - 1 - i));
    });
  }

  /// Normalizes date to midnight (00:00:00)
  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
