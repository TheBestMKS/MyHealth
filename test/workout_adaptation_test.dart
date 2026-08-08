import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/model.dart';
import 'package:my_health/src/workout_adaptation.dart';

void main() {
  WorkoutSession workout({
    required String id,
    required String date,
    int minutes = 40,
    String status = 'planned',
    int effort = 0,
    String feedback = '',
  }) => WorkoutSession(
    id: id,
    title: id,
    focus: 'силовая',
    minutes: minutes,
    intensity: 'средняя',
    scheduledDate: date,
    exerciseIds: const ['push-up'],
    status: status,
    perceivedEffort: effort,
    feedback: feedback,
  );

  test('high effort safely reduces the next two planned sessions', () {
    final completed = workout(
      id: 'done',
      date: '2026-07-13',
      status: 'completed',
      effort: 9,
    );
    final result = adaptFutureWorkoutPlan([
      completed,
      workout(id: 'next', date: '2026-07-14', minutes: 50),
      workout(id: 'later', date: '2026-07-16', minutes: 50),
    ], completed);

    expect(result[1].minutes, 30);
    expect(result[1].intensity, 'восстановительная');
    expect(result[2].minutes, 40);
    expect(result[2].intensity, 'низкая');
    expect(result[1].notes, contains('автоматически облегчен'));
  });

  test('an easy session progresses only the nearest future plan', () {
    final completed = workout(
      id: 'done',
      date: '2026-07-13',
      status: 'completed',
      effort: 3,
      feedback: 'слишком легко',
    );
    final result = adaptFutureWorkoutPlan([
      completed,
      workout(id: 'next', date: '2026-07-14', minutes: 40),
      workout(id: 'later', date: '2026-07-16', minutes: 40),
    ], completed);

    expect(result[1].minutes, 44);
    expect(result[2].minutes, 40);
  });
}
