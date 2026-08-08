import 'model.dart';

String formatWeight(double kilograms, AppSettings settings) {
  if (settings.bodyWeightUnit == 'lb') {
    return '${(kilograms * 2.2046226218).toStringAsFixed(1)} lb';
  }
  return '${kilograms.toStringAsFixed(1)} кг';
}

String formatHeight(double centimeters, AppSettings settings) {
  if (settings.heightUnit == 'ft') {
    final totalInches = centimeters / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches - feet * 12).round();
    return '$feet′ $inches″';
  }
  return '${centimeters.toStringAsFixed(0)} см';
}

String formatDistance(double meters, AppSettings settings, {int digits = 2}) {
  if (settings.distanceUnit == 'mi') {
    return '${(meters / 1609.344).toStringAsFixed(digits)} mi';
  }
  return '${(meters / 1000).toStringAsFixed(digits)} км';
}

String formatSpeed(double kilometersPerHour, AppSettings settings) {
  if (settings.distanceUnit == 'mi') {
    return '${(kilometersPerHour / 1.609344).toStringAsFixed(1)} mph';
  }
  return '${kilometersPerHour.toStringAsFixed(1)} км/ч';
}

String formatTemperature(double celsius, AppSettings settings) {
  if (settings.temperatureUnit == 'fahrenheit') {
    return '${(celsius * 9 / 5 + 32).toStringAsFixed(1)} °F';
  }
  return '${celsius.toStringAsFixed(1)} °C';
}

String formatDisplayDate(String value, AppSettings settings) {
  final date = parseDateKey(value);
  if (date == null) return value;
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return switch (settings.dateDisplayFormat) {
    'dd/mm/yyyy' => '$day/$month/${date.year}',
    'mm/dd/yyyy' => '$month/$day/${date.year}',
    _ => '$day.$month.${date.year}',
  };
}

String formatTimeValue(String value, AppSettings settings) {
  if (settings.timeFormat != '12h') return value;
  final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(value);
  if (match == null) return value;
  final hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final clockHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$clockHour:$minute $suffix';
}
