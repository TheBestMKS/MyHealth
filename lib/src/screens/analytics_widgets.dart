part of '../screens.dart';

class _TrendPoint {
  const _TrendPoint(this.date, this.value);

  final String date;
  final double value;
}

class _HealthTrendChart extends StatelessWidget {
  const _HealthTrendChart({
    required this.title,
    required this.unit,
    required this.color,
    required this.points,
    this.target,
  });

  final String title;
  final String unit;
  final Color color;
  final List<_TrendPoint> points;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final visible = sorted.length > 30
        ? sorted.sublist(sorted.length - 30)
        : sorted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (visible.isNotEmpty)
                  Text('${visible.last.value.toStringAsFixed(1)} $unit'),
              ],
            ),
            const SizedBox(height: 8),
            if (visible.length < 2)
              const SizedBox(
                height: 90,
                child: Center(
                  child: Text('Нужно минимум две записи для графика'),
                ),
              )
            else ...[
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    points: visible,
                    color: color,
                    target: target,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    gridColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _trendSummary(visible, unit, target),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.points,
    required this.color,
    required this.target,
    required this.textColor,
    required this.gridColor,
  });

  final List<_TrendPoint> points;
  final Color color;
  final double? target;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const top = 10.0;
    const bottom = 24.0;
    final width = size.width - left - 8;
    final height = size.height - top - bottom;
    final values = [...points.map((item) => item.value), ?target];
    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);
    if (minValue == maxValue) {
      minValue -= 1;
      maxValue += 1;
    }
    final padding = (maxValue - minValue) * 0.12;
    minValue -= padding;
    maxValue += padding;
    double x(int index) => left + width * index / (points.length - 1);
    double y(double value) =>
        top + height * (1 - (value - minValue) / (maxValue - minValue));

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final dy = top + height * index / 3;
      canvas.drawLine(Offset(left, dy), Offset(size.width - 8, dy), gridPaint);
      final value = maxValue - (maxValue - minValue) * index / 3;
      _paintLabel(canvas, value.toStringAsFixed(0), Offset(0, dy - 7));
    }

    if (target != null) {
      final targetPaint = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 1.5;
      final dy = y(target!);
      canvas.drawLine(
        Offset(left, dy),
        Offset(size.width - 8, dy),
        targetPaint,
      );
    }

    final line = Path()..moveTo(x(0), y(points.first.value));
    for (var index = 1; index < points.length; index++) {
      line.lineTo(x(index), y(points[index].value));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final pointPaint = Paint()..color = color;
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(
        Offset(x(index), y(points[index].value)),
        3,
        pointPaint,
      );
    }
    _paintLabel(
      canvas,
      displayDateKey(points.first.date).substring(0, 5),
      Offset(left, size.height - 18),
    );
    final lastText = displayDateKey(points.last.date).substring(0, 5);
    final textPainter = _textPainter(lastText);
    textPainter.paint(
      canvas,
      Offset(size.width - 8 - textPainter.width, size.height - 18),
    );
  }

  TextPainter _textPainter(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: textColor, fontSize: 10),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    _textPainter(text).paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.target != target;
}

String _trendSummary(List<_TrendPoint> points, String unit, double? target) {
  final first = points.first.value;
  final last = points.last.value;
  final delta = last - first;
  final direction = delta.abs() < 0.01
      ? 'стабильно'
      : delta > 0
      ? 'рост'
      : 'снижение';
  final targetText = target == null
      ? ''
      : last >= target
      ? ' Целевой ориентир достигнут.'
      : ' До ориентира ${(target - last).toStringAsFixed(1)} $unit.';
  return '$direction за ${points.length} записей: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} $unit.$targetText';
}

List<Widget> _labTrendCharts(List<LabResult> labs) {
  final groups = <String, List<_TrendPoint>>{};
  final units = <String, String>{};
  for (final lab in labs) {
    final value = double.tryParse(lab.value.replaceAll(',', '.'));
    if (value == null) continue;
    groups.putIfAbsent(lab.marker, () => []).add(_TrendPoint(lab.date, value));
    units[lab.marker] = lab.unit;
  }
  return groups.entries
      .where((entry) => entry.value.length >= 2)
      .take(8)
      .map(
        (entry) => _HealthTrendChart(
          title: entry.key,
          unit: units[entry.key] ?? '',
          color: Colors.purple,
          points: entry.value,
        ),
      )
      .toList();
}

List<_TrendPoint> _symptomTrendPoints(HealthAppState state) {
  final byDate = <String, int>{};
  for (final entry in state.symptomEntries) {
    byDate.update(entry.date, (value) => value + 1, ifAbsent: () => 1);
  }
  for (final metric in state.dailyHistory) {
    if (metric.symptoms.isNotEmpty) {
      byDate.update(
        metric.date,
        (value) => value + metric.symptoms.length,
        ifAbsent: () => metric.symptoms.length,
      );
    }
  }
  return byDate.entries
      .map((entry) => _TrendPoint(entry.key, entry.value.toDouble()))
      .toList();
}

List<_TrendPoint> _medicationAdherencePoints(HealthAppState state) {
  final byDate = <String, List<MedicationIntake>>{};
  for (final intake in state.medicationIntakes) {
    byDate.putIfAbsent(intake.date, () => []).add(intake);
  }
  return byDate.entries.map((entry) {
    final resolved = entry.value.where(
      (item) => item.status == 'принято' || item.status == 'пропущено',
    );
    final taken = resolved.where((item) => item.status == 'принято').length;
    final percent = resolved.isEmpty ? 0 : taken * 100 / resolved.length;
    return _TrendPoint(entry.key, percent.toDouble());
  }).toList();
}

List<_TrendPoint> _mealNutrientPoints(
  HealthAppState state,
  int Function(MealEntry meal) valueOf,
) {
  final byDate = <String, int>{};
  for (final meal in state.meals.where((item) => item.confirmed)) {
    final date = meal.date.isEmpty ? state.today.date : meal.date;
    byDate.update(
      date,
      (value) => value + valueOf(meal),
      ifAbsent: () => valueOf(meal),
    );
  }
  return byDate.entries
      .where((entry) => entry.value > 0)
      .map((entry) => _TrendPoint(entry.key, entry.value.toDouble()))
      .toList();
}

List<String> _analyticsInterpretations(HealthAppState state) {
  final result = <String>[];
  final history = [...state.dailyHistory]
    ..sort((a, b) => a.date.compareTo(b.date));
  final recent = history.length > 7
      ? history.sublist(history.length - 7)
      : history;
  if (recent.length >= 3) {
    final sleep = recent
        .map((item) => item.sleepHours)
        .where((value) => value > 0);
    if (sleep.isNotEmpty) {
      final average = sleep.reduce((a, b) => a + b) / sleep.length;
      result.add(
        average < 6.5
            ? 'Средний сон ${average.toStringAsFixed(1)} ч: восстановление ниже ориентира.'
            : 'Средний сон ${average.toStringAsFixed(1)} ч: режим выглядит устойчиво.',
      );
    }
    final steps = recent.map((item) => item.steps).where((value) => value > 0);
    if (steps.isNotEmpty) {
      final average = steps.reduce((a, b) => a + b) / steps.length;
      result.add(
        average < 5000
            ? 'Средняя активность ${average.round()} шагов: полезно добавить короткие прогулки.'
            : 'Средняя активность ${average.round()} шагов: базовое движение поддерживается.',
      );
    }
  }
  final missed = state.medicationIntakes
      .where((item) => item.status == 'пропущено')
      .length;
  if (missed > 0) result.add('В журнале лекарств отмечено пропусков: $missed.');
  final painful = state.workouts.where(
    (item) => item.exerciseResults.any((result) => result.pain),
  );
  if (painful.isNotEmpty) {
    result.add(
      'В тренировках отмечалась боль: будущую нагрузку стоит снизить.',
    );
  }
  final missedWorkouts = state.workouts
      .where((item) => item.status == 'missed' || item.status == 'cancelled')
      .length;
  if (missedWorkouts >= 2) {
    result.add(
      'Пропущено тренировок: $missedWorkouts. План лучше сократить и не переносить две тяжёлые нагрузки подряд.',
    );
  }
  final repeatedSymptoms = <String, int>{};
  for (final symptom in state.symptomEntries) {
    repeatedSymptoms.update(
      symptom.symptom.toLowerCase(),
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  final repeated = repeatedSymptoms.entries
      .where((entry) => entry.value >= 3)
      .map((entry) => '${entry.key} (${entry.value})')
      .take(3)
      .toList();
  if (repeated.isNotEmpty) {
    result.add(
      'Повторяющиеся симптомы: ${repeated.join(', ')}. Полезно показать дневник специалисту.',
    );
  }
  final nowKey = todayKey();
  final activeTrips = state.trips.where(
    (item) =>
        item.startDate.compareTo(nowKey) <= 0 &&
        item.endDate.compareTo(nowKey) >= 0,
  );
  final activeVacations = state.workSchedule.vacations.where(
    (item) =>
        item.startDate.compareTo(nowKey) <= 0 &&
        item.endDate.compareTo(nowKey) >= 0,
  );
  if (activeTrips.isNotEmpty || activeVacations.isNotEmpty) {
    result.add(
      'Сейчас активен режим поездки: при ночной дороге, смене часового пояса или недосыпе нагрузка автоматически считается восстановительной.',
    );
  }
  if (result.isEmpty) {
    result.add(
      'Добавляйте записи несколько дней подряд, чтобы увидеть устойчивые изменения.',
    );
  }
  return result;
}
