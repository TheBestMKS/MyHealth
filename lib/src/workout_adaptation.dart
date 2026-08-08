import 'model.dart';

List<WorkoutSession> adaptFutureWorkoutPlan(
  List<WorkoutSession> workouts,
  WorkoutSession completed,
) {
  final painful = completed.exerciseResults.any((item) => item.pain);
  final tooHard =
      painful ||
      completed.perceivedEffort >= 8 ||
      completed.exerciseResults.any(
        (item) => item.difficulty.toLowerCase().contains('тяж'),
      ) ||
      completed.feedback.toLowerCase().contains('боль');
  final tooEasy =
      !tooHard &&
      completed.perceivedEffort > 0 &&
      completed.perceivedEffort <= 4 &&
      (completed.feedback.toLowerCase().contains('легк') ||
          completed.exerciseResults.any(
            (item) => item.difficulty.toLowerCase().contains('легк'),
          ));
  if (!tooHard && !tooEasy) return workouts;

  final future =
      workouts
          .where(
            (item) =>
                item.id != completed.id &&
                item.status == 'planned' &&
                item.scheduledDate.compareTo(completed.scheduledDate) > 0,
          )
          .toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  final affected = future.take(tooHard ? 2 : 1).toList();
  if (affected.isEmpty) return workouts;

  return workouts.map((item) {
    final index = affected.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0) return item;
    if (tooHard) {
      final multiplier = index == 0 ? 0.6 : 0.8;
      final reason = painful
          ? 'План автоматически облегчен после отметки боли.'
          : 'План автоматически облегчен после высокой субъективной нагрузки.';
      return item.copyWith(
        minutes: (item.minutes * multiplier).round().clamp(10, 600),
        intensity: index == 0 ? 'восстановительная' : 'низкая',
        notes: _appendAdaptationNote(item.notes, reason),
      );
    }
    return item.copyWith(
      minutes: (item.minutes * 1.1).round().clamp(10, 600),
      notes: _appendAdaptationNote(
        item.notes,
        'Длительность увеличена на 10% после слишком лёгкой нагрузки.',
      ),
    );
  }).toList();
}

String _appendAdaptationNote(String source, String note) {
  if (source.contains(note)) return source;
  return [source.trim(), note].where((item) => item.isNotEmpty).join(' ');
}
