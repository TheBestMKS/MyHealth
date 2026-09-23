import 'model.dart';

enum PlanSeverity { info, attention, urgent }

class PlanRecommendation {
  const PlanRecommendation({
    required this.title,
    required this.detail,
    required this.section,
    this.severity = PlanSeverity.info,
  });

  final String title;
  final String detail;
  final String section;
  final PlanSeverity severity;
}

class IntegratedHealthPlan {
  const IntegratedHealthPlan({
    required this.recommendations,
    required this.summary,
  });

  final List<PlanRecommendation> recommendations;
  final String summary;

  bool get hasUrgent =>
      recommendations.any((item) => item.severity == PlanSeverity.urgent);
}

IntegratedHealthPlan buildIntegratedHealthPlan(
  HealthAppState state, {
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  final date = todayKey(moment);
  final items = <PlanRecommendation>[];
  final symptoms = state.symptomEntries
      .where((item) => item.date == date)
      .toList();
  final urgentSymptoms = symptoms.where(
    (item) =>
        item.needsAttention ||
        item.intensity >= 8 ||
        (item.temperatureC ?? 0) >= 38.5 ||
        (item.systolic ?? 0) >= 180 ||
        (item.diastolic ?? 0) >= 120,
  );
  if (urgentSymptoms.isNotEmpty) {
    items.add(
      PlanRecommendation(
        title: 'Сначала оцените тревожные симптомы',
        detail:
            '${urgentSymptoms.map((item) => item.symptom).join(', ')}. Отложите тренировку; при резком ухудшении или опасных признаках обратитесь за неотложной помощью.',
        section: 'symptoms',
        severity: PlanSeverity.urgent,
      ),
    );
  }

  final glucose = state.labResults
      .where(
        (item) =>
            item.marker.toLowerCase().contains('глюкоз') ||
            item.marker.toLowerCase().contains('сахар'),
      )
      .firstOrNull;
  if (glucose != null) {
    final value = double.tryParse(glucose.value.replaceAll(',', '.'));
    if (value != null && (value < 3.9 || value > 10)) {
      items.add(
        PlanRecommendation(
          title: 'Проверьте глюкозу и личный план',
          detail:
              'Последняя запись: ${glucose.value} ${glucose.unit}. Повторите измерение по правилам устройства и следуйте плану, согласованному с врачом. Приложение не рассчитывает дозу инсулина.',
          section: 'labs',
          severity: value < 3 || value > 13.9
              ? PlanSeverity.urgent
              : PlanSeverity.attention,
        ),
      );
    }
  }

  final activeVacation = state.workSchedule.vacations.where(
    (item) =>
        item.startDate.compareTo(date) <= 0 &&
        item.endDate.compareTo(date) >= 0,
  );
  final activeTrip = state.trips.where(
    (item) =>
        item.startDate.compareTo(date) <= 0 &&
        item.endDate.compareTo(date) >= 0,
  );
  final duty = state.workSchedule.duties.where((item) => item.date == date);
  if (duty.isNotEmpty) {
    final item = duty.first;
    items.add(
      PlanRecommendation(
        title: 'Сегодня дежурство',
        detail:
            'Дежурство ${item.startTime}–${item.endTime}; прибытие ${item.arrivalTime.isEmpty ? 'по графику' : item.arrivalTime}. Тяжёлую тренировку ставьте только при достаточном сне и времени на восстановление.',
        section: 'calendar',
        severity: PlanSeverity.attention,
      ),
    );
  } else if (activeTrip.isNotEmpty) {
    final trip = activeTrip.first;
    items.add(
      PlanRecommendation(
        title: 'План адаптирован к командировке',
        detail:
            '${trip.city.isEmpty ? trip.title : trip.city}: дорога ${trip.travelMinutes} мин, смещение времени ${trip.timeZoneShift} ч. Выберите ${trip.gymAvailable
                ? 'зал'
                : trip.roomWorkoutAvailable
                ? 'короткую тренировку в номере'
                : 'восстановительную прогулку'}.',
        section: 'trips',
        severity: trip.nightTravel || !trip.sleepInTransit
            ? PlanSeverity.attention
            : PlanSeverity.info,
      ),
    );
  } else if (activeVacation.isNotEmpty) {
    final vacation = activeVacation.first;
    items.add(
      PlanRecommendation(
        title: 'Действует режим отпуска',
        detail:
            '${vacation.city.isEmpty ? vacation.title : vacation.city}: ${vacation.walkingAvailable ? 'доступны прогулки' : 'учтите ограниченную активность'}${vacation.nightTravel ? '; после ночной дороги снизьте нагрузку' : ''}.',
        section: 'vacation',
      ),
    );
  }

  final unrecordedMedicines = state.medications.where(
    (medicine) =>
        _hasTimeAtOrBefore(medicine.schedule, moment) &&
        !state.medicationTakenOnDate(medicine, date),
  );
  if (unrecordedMedicines.isNotEmpty) {
    items.add(
      PlanRecommendation(
        title: 'Сверьте приём лекарств',
        detail:
            'Нет отметки: ${unrecordedMedicines.take(4).map((item) => item.name).join(', ')}. Отмечайте только фактически принятые дозы и не принимайте двойную дозу без инструкции врача.',
        section: 'medicines',
        severity: PlanSeverity.attention,
      ),
    );
  }
  final lowStock = state.medications.where((item) => item.stockIsLow);
  if (lowStock.isNotEmpty) {
    items.add(
      PlanRecommendation(
        title: 'Пополните запас препаратов',
        detail: lowStock
            .take(4)
            .map((item) => '${item.name}: ${item.remainingUnits}')
            .join(', '),
        section: 'medicines',
        severity: PlanSeverity.attention,
      ),
    );
  }

  final unsafe = urgentSymptoms.isNotEmpty;
  if (!unsafe &&
      (state.today.sleepHours > 0 && state.today.sleepHours < 6 ||
          state.readinessScore < 50)) {
    items.add(
      const PlanRecommendation(
        title: 'Снизьте тренировочную нагрузку',
        detail:
            'Недостаток сна или низкая готовность: выберите 10–25 минут прогулки, мобильности или лёгкой техники вместо тяжёлой сессии.',
        section: 'workouts',
        severity: PlanSeverity.attention,
      ),
    );
  } else if (!unsafe) {
    final planned = state.workouts.where(
      (item) => item.scheduledDate == date && item.status == 'planned',
    );
    items.add(
      PlanRecommendation(
        title: planned.isEmpty
            ? 'Запланируйте посильную активность'
            : 'Тренировка согласована с готовностью',
        detail: planned.isEmpty
            ? 'Цель активности: ${state.activityReminders.activeMinutesTarget} мин. Учитывайте ограничения и самочувствие.'
            : '${planned.first.title}, ${planned.first.minutes} мин. Остановитесь при боли, головокружении или необычной одышке.',
        section: 'workouts',
      ),
    );
  }

  final todayMeals = state.meals.where(
    (item) => item.date.isEmpty || item.date == date,
  );
  final protein = todayMeals.fold<int>(0, (sum, item) => sum + item.protein);
  final allergyMatches = todayMeals.where((meal) {
    final text = '${meal.title} ${meal.notes}'.toLowerCase();
    return state.allergies.any((allergy) {
      final term = allergy.toLowerCase().trim();
      return term.length >= 3 && text.contains(term);
    });
  });
  if (allergyMatches.isNotEmpty) {
    items.add(
      PlanRecommendation(
        title: 'Проверьте аллерген в дневнике',
        detail:
            'В названиях или заметках есть совпадение: ${allergyMatches.map((item) => item.title).join(', ')}. Это текстовая проверка, подтвердите состав по упаковке.',
        section: 'nutrition',
        severity: PlanSeverity.attention,
      ),
    );
  } else if (state.today.calories > 0 && protein < 45) {
    items.add(
      PlanRecommendation(
        title: 'Проверьте белок и полноту дневника',
        detail:
            'По внесённым приёмам пищи: $protein г белка. Это не персональная норма; добавьте пропущенные блюда и учитывайте ограничения.',
        section: 'nutrition',
      ),
    );
  }
  if (state.today.waterLiters < 1.2 && moment.hour >= 14) {
    items.add(
      PlanRecommendation(
        title: 'Вода отстаёт от обычного темпа',
        detail:
            'Записано ${state.today.waterLiters.toStringAsFixed(1)} л. Пейте небольшими порциями, если врач не ограничил жидкость.',
        section: 'nutrition',
      ),
    );
  }

  if (state.confirmationQueue.isNotEmpty) {
    items.add(
      PlanRecommendation(
        title: 'Есть данные для ручной проверки',
        detail:
            'Кандидатов OCR и фото: ${state.confirmationQueue.length}. Не используйте распознанные назначения до сверки с оригиналом.',
        section: 'documents',
        severity: PlanSeverity.attention,
      ),
    );
  }

  final urgent = items
      .where((item) => item.severity == PlanSeverity.urgent)
      .length;
  final attention = items
      .where((item) => item.severity == PlanSeverity.attention)
      .length;
  final summary = urgent > 0
      ? 'Есть $urgent срочных пунктов; начните с них.'
      : attention > 0
      ? 'Нужно проверить $attention пунктов; остальные планы можно выполнять по самочувствию.'
      : 'Критичных конфликтов в заполненных данных не найдено.';
  return IntegratedHealthPlan(
    recommendations: List.unmodifiable(items),
    summary: summary,
  );
}

bool _hasTimeAtOrBefore(String schedule, DateTime now) {
  final times = RegExp(
    r'\b(?:[01]?\d|2[0-3]):[0-5]\d\b',
  ).allMatches(schedule).map((match) => match.group(0)!).toList();
  if (times.isEmpty) return now.hour >= 20;
  final currentMinutes = now.hour * 60 + now.minute;
  return times.any((value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]) <= currentMinutes;
  });
}
