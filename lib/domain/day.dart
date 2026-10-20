/// A calendar day in the user's local time, with no time-of-day.
class DayKey implements Comparable<DayKey> {
  const DayKey(this.year, this.month, this.day);

  factory DayKey.fromDateTime(DateTime t) => DayKey(t.year, t.month, t.day);

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  DayKey addDays(int n) => DayKey.fromDateTime(_utc.add(Duration(days: n)));

  /// Whole days from this day to [other]; negative if [other] is earlier.
  int daysUntil(DayKey other) => other._utc.difference(_utc).inDays;

  /// Local time on this day at [minuteOfDay] minutes after midnight.
  /// Values of 1440 or more roll into the following day.
  DateTime at(int minuteOfDay) => DateTime(year, month, day, 0, minuteOfDay);

  bool isBefore(DayKey other) => compareTo(other) < 0;
  bool isAfter(DayKey other) => compareTo(other) > 0;

  @override
  int compareTo(DayKey other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) =>
      other is DayKey &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
