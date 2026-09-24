import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/assistant_background_service.dart';
import 'package:my_health/src/model.dart';

void main() {
  test(
    'background assistant queues commands and preserves newer state',
    () async {
      var state = HealthAppState.seed();
      final service = AssistantBackgroundService();
      service.bind(readState: () => state, writeState: (next) => state = next);

      final jobId = service.enqueueText(query: 'Добавь 300 мл воды');
      state = state.copyWith(profile: state.profile.copyWith(name: 'Игорь'));

      expect(jobId, isNotEmpty);
      expect(state.today.waterLiters, 0);
      await service.waitUntilIdle();

      expect(state.profile.name, 'Игорь');
      expect(state.today.waterLiters, closeTo(0.3, 0.001));
      expect(state.assistantMessages, hasLength(2));
      expect(service.status.value.busy, isFalse);
      service.unbind();
    },
  );

  test('background assistant processes queued actions in order', () async {
    var state = HealthAppState.seed();
    final service = AssistantBackgroundService();
    service.bind(readState: () => state, writeState: (next) => state = next);

    service.enqueueText(query: 'Я выпил 250 мл воды');
    service.enqueueText(query: 'Я выпил 1 стакан воды');
    await service.waitUntilIdle();

    expect(state.today.waterLiters, closeTo(0.5, 0.001));
    expect(state.assistantMessages, hasLength(4));
    service.unbind();
  });
}
