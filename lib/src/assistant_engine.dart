import 'model.dart';

class AssistantAnswer {
  const AssistantAnswer({
    required this.text,
    required this.relatedSection,
    required this.confidence,
  });

  final String text;
  final String relatedSection;
  final double confidence;
}

AssistantAnswer buildAssistantAnswer(HealthAppState state, String query) {
  final lower = query.toLowerCase();
  final relatedSection = assistantRelatedSection(query);
  final facts = <String>[];
  final assumptions = <String>[];
  final actions = <String>[];
  final missing = <String>[];
  var evidence = 0;
  var expectedEvidence = 2;

  void fact(String value) {
    facts.add(value);
    evidence++;
  }

  final asksMedication = _containsAny(lower, [
    'лекар',
    'таблет',
    'доз',
    'остат',
    'medicine',
    'medication',
  ]);
  final asksWorkout = _containsAny(lower, [
    'трен',
    'нагруз',
    'спорт',
    'бег',
    'workout',
    'exercise',
  ]);
  final asksNutrition = _containsAny(lower, [
    'питан',
    'ед',
    'калори',
    'белок',
    'food',
    'nutrition',
    'calorie',
  ]);
  final asksSleep = _containsAny(lower, [
    'сон',
    'спал',
    'будил',
    'sleep',
    'alarm',
  ]);
  final asksLabs = _containsAny(lower, [
    'анализ',
    'показател',
    'референс',
    'lab',
    'blood test',
  ]);
  final asksSymptoms = _containsAny(lower, [
    'симптом',
    'боль',
    'температур',
    'самочув',
    'symptom',
    'pain',
  ]);
  final asksDocuments = _containsAny(lower, [
    'документ',
    'врач',
    'выписк',
    'рецепт',
    'document',
    'doctor',
  ]);
  final asksTravelClimate = _containsAny(lower, [
    'поезд',
    'отпуск',
    'командиров',
    'климат',
    'жар',
    'холод',
    'travel',
    'vacation',
    'climate',
  ]);
  final general =
      !asksMedication &&
      !asksWorkout &&
      !asksNutrition &&
      !asksSleep &&
      !asksLabs &&
      !asksSymptoms &&
      !asksDocuments &&
      !asksTravelClimate;

  if (general || asksWorkout || asksSleep) {
    expectedEvidence += 3;
    if (state.today.sleepHours > 0) {
      fact('сон сегодня: ${state.today.sleepHours.toStringAsFixed(1)} ч.');
    } else {
      missing.add('длительность сна за сегодня');
    }
    if (state.today.waterLiters > 0) {
      fact('вода сегодня: ${state.today.waterLiters.toStringAsFixed(1)} л.');
    } else {
      missing.add('вода за сегодня');
    }
    fact(
      'расчётная готовность ${state.readinessScore}/100 и энергия ${state.energyScore}/100.',
    );
  }

  if (general || asksMedication) {
    expectedEvidence += 2;
    if (state.medications.isEmpty) {
      missing.add('назначенные лекарства');
      if (asksMedication) {
        actions.add(
          'не начинайте, не отменяйте и не меняйте дозировку лекарства самостоятельно; сверьтесь с назначением врача.',
        );
      }
    } else {
      final taken = state.medicationTakenCount(state.today.date);
      final lowStock = state.medications
          .where((item) => item.stockIsLow)
          .toList();
      fact(
        'в плане ${state.medications.length} препаратов, принято сегодня $taken.',
      );
      if (lowStock.isNotEmpty) {
        fact(
          'низкий остаток: ${lowStock.map((item) => '${item.name} (${item.remainingUnits})').join(', ')}.',
        );
        actions.add('проверьте запас и заранее запланируйте покупку.');
      }
      if (taken < state.medications.length) {
        actions.add(
          'сверьте непринятые препараты с назначением и расписанием; дозировку не меняйте самостоятельно.',
        );
      }
    }
  }

  if (general || asksWorkout) {
    expectedEvidence += 3;
    final planned = state.workouts
        .where(
          (item) =>
              item.scheduledDate == state.today.date &&
              item.status == 'planned',
        )
        .toList();
    final pain = state.symptomEntries.any(
      (item) =>
          item.date == state.today.date &&
          (item.needsAttention ||
              item.intensity >= 8 ||
              (item.temperatureC ?? 0) >= 38),
    );
    if (planned.isNotEmpty) {
      fact(
        'на сегодня запланировано: ${planned.map((item) => '${item.title}, ${item.minutes} мин').join('; ')}.',
      );
    } else {
      missing.add('тренировка на сегодня');
    }
    if (pain) {
      fact(
        'сегодня отмечен тревожный симптом или высокая интенсивность жалобы.',
      );
      assumptions.add(
        'обычную или тяжёлую тренировку безопаснее отложить до улучшения самочувствия.',
      );
      actions.add(
        'не тренируйтесь через боль или температуру; при резком ухудшении обратитесь за медицинской помощью.',
      );
    } else if (state.readinessScore < 55 ||
        (state.today.sleepHours > 0 && state.today.sleepHours < 6)) {
      assumptions.add(
        'по текущей готовности предпочтительна короткая восстановительная нагрузка, прогулка или мобильность.',
      );
    } else {
      assumptions.add(
        'по внесённым данным допустима обычная плановая нагрузка с контролем самочувствия.',
      );
    }
  }

  if (general || asksNutrition) {
    expectedEvidence += 3;
    if (state.meals.isEmpty && state.today.calories == 0) {
      missing.add('приёмы пищи и калории за сегодня');
    } else {
      final protein = state.meals
          .where((item) => item.date.isEmpty || item.date == state.today.date)
          .fold<int>(0, (sum, item) => sum + item.protein);
      fact(
        'питание сегодня: ${state.today.calories} ккал, белок по записям $protein г.',
      );
      final bmr = state.profile.basalMetabolicRate;
      if (bmr > 0) {
        fact(
          'расчётный основной обмен: ${bmr.round()} ккал/сутки; это не персональная норма питания.',
        );
        if (state.today.calories > bmr * 1.8) {
          assumptions.add(
            'внесённая калорийность заметно выше основного обмена, но недельный баланс и активность важнее одного дня.',
          );
          actions.add(
            'не компенсируйте еду голоданием; выберите спокойную прогулку и вернитесь к обычному плану.',
          );
        } else if (state.today.calories > 0 &&
            state.today.calories < bmr * 0.65) {
          assumptions.add(
            'внесённая калорийность низкая относительно основного обмена; возможно, дневник заполнен не полностью.',
          );
          actions.add(
            'проверьте пропущенные приёмы пищи и не снижайте рацион резко без специалиста.',
          );
        }
      } else {
        missing.add('рост, масса, дата рождения и пол для расчёта обмена');
      }
    }
  }

  if (general || asksLabs) {
    expectedEvidence += 2;
    final outside = state.labResults
        .where((item) => item.outsideReference)
        .toList();
    final pending = state.confirmationQueue
        .where((item) => item.requiresMedicalReview)
        .length;
    if (state.labResults.isNotEmpty) {
      fact(
        'сохранено анализов: ${state.labResults.length}, вне референса или для проверки: ${outside.length}.',
      );
      if (outside.isNotEmpty) {
        actions.add(
          'обсудите с врачом: ${outside.take(5).map((item) => '${item.marker} (${item.referenceStatus})').join(', ')}.',
        );
      }
    } else {
      missing.add('подтверждённые результаты анализов');
    }
    if (pending > 0) {
      fact('ожидают ручной проверки результатов OCR: $pending.');
      actions.add('сначала сравните OCR с исходным документом.');
    }
  }

  if (general || asksSymptoms) {
    expectedEvidence += 2;
    final recent = state.symptomEntries
        .where((item) => item.date.compareTo(state.today.date) <= 0)
        .take(7)
        .toList();
    if (recent.isEmpty) {
      missing.add('записи самочувствия и симптомов');
    } else {
      fact(
        'последние симптомы: ${recent.map((item) => '${item.symptom} ${item.intensity}/10').join(', ')}.',
      );
      if (recent.any(
        (item) =>
            item.needsAttention ||
            item.intensity >= 8 ||
            (item.temperatureC ?? 0) >= 38,
      )) {
        actions.add(
          'есть тревожная отметка: при сохранении или усилении симптомов обратитесь к специалисту.',
        );
      }
    }
  }

  if (general || asksDocuments) {
    expectedEvidence += 2;
    if (state.documents.isEmpty) {
      missing.add('медицинские документы');
    } else {
      final tagged = state.documents
          .where((item) => item.tags.isNotEmpty)
          .length;
      fact('документов: ${state.documents.length}, с тегами: $tagged.');
      actions.add(
        'для врача подготовьте актуальные анализы, назначения, список препаратов и связанные документы.',
      );
    }
    if (state.careProviders.isNotEmpty) {
      fact('врачей и клиник в медкарте: ${state.careProviders.length}.');
    }
  }

  if (general || asksSleep) {
    expectedEvidence += 2;
    if (state.sleepRecords.isNotEmpty) {
      final latest = state.sleepRecords.first;
      fact(
        'последняя запись сна: ${latest.durationHours.toStringAsFixed(1)} ч, качество ${latest.quality}/5, пробуждений ${latest.awakenings}.',
      );
      if (latest.durationHours < 6) {
        assumptions.add(
          'недосып может снизить восстановление и переносимость тяжёлой нагрузки.',
        );
      }
    } else {
      missing.add('подробная запись сна');
    }
    final smartAlarms = state.alarmGroups
        .where((item) => item.useWearableSleepCycle)
        .length;
    fact(
      'будильников: ${state.alarmGroups.length}, с окном по циклам сна: $smartAlarms.',
    );
  }

  if (general || asksTravelClimate) {
    expectedEvidence += 2;
    final activeTrip = state.trips
        .where(
          (item) =>
              item.startDate.compareTo(state.today.date) <= 0 &&
              item.endDate.compareTo(state.today.date) >= 0,
        )
        .firstOrNull;
    final activeVacation = state.workSchedule.vacations
        .where(
          (item) =>
              item.startDate.compareTo(state.today.date) <= 0 &&
              item.endDate.compareTo(state.today.date) >= 0,
        )
        .firstOrNull;
    if (activeTrip != null) {
      fact(
        'активна командировка ${activeTrip.city}: ${activeTrip.adjustment}.',
      );
      if (activeTrip.nightTravel ||
          activeTrip.sleepInTransit ||
          activeTrip.timeZoneShift.abs() >= 3) {
        assumptions.add(
          'дорога и смена часового пояса повышают потребность в восстановлении.',
        );
      }
    } else if (activeVacation != null) {
      fact(
        'активен отпуск: ${activeVacation.country}, ${activeVacation.city}.',
      );
      if (activeVacation.nightTravel || activeVacation.sleepInTransit) {
        assumptions.add(
          'после ночной дороги лучше начать с воды, сна, прогулки и лёгкой мобильности.',
        );
      }
    } else {
      fact('активных поездок или отпуска сегодня нет.');
    }
    if (state.profile.climate.isNotEmpty) {
      fact('профиль климата: ${state.profile.city}, ${state.profile.climate}.');
    } else {
      missing.add('климатический профиль места');
    }
  }

  if (facts.isEmpty) {
    facts.add('по этому вопросу в приложении пока нет подтверждённых записей.');
  }
  if (assumptions.isEmpty) {
    assumptions.add(
      'вывод ограничен полнотой дневника и не заменяет оценку специалиста.',
    );
  }
  if (actions.isEmpty) {
    actions.add(
      'проверьте исходные записи и добавьте недостающие измерения перед решением.',
    );
  }

  final confidence = (evidence / expectedEvidence).clamp(0.2, 0.92).toDouble();
  final lines = <String>[
    'Справочно, без диагноза, назначения или отмены лечения.',
    'Факты из приложения:',
    ...facts.map((item) => '- $item'),
    'Предположения, уверенность ${(confidence * 100).round()}%:',
    ...assumptions.map((item) => '- $item'),
    'Следующие действия:',
    ...actions.map((item) => '- $item'),
    if (missing.isNotEmpty) 'Не хватает данных:',
    ...missing.toSet().map((item) => '- $item'),
    'При тревожных симптомах или сомнениях обратитесь к врачу.',
  ];
  return AssistantAnswer(
    text: lines.join('\n'),
    relatedSection: relatedSection,
    confidence: confidence,
  );
}

String assistantRelatedSection(String query) {
  final lower = query.toLowerCase();
  if (_containsAny(lower, ['лекар', 'таблет', 'medicine', 'medication'])) {
    return 'medicines';
  }
  if (_containsAny(lower, ['трен', 'нагруз', 'спорт', 'workout', 'exercise'])) {
    return 'workouts';
  }
  if (_containsAny(lower, ['питан', 'еда', 'калори', 'food', 'nutrition'])) {
    return 'nutrition';
  }
  if (_containsAny(lower, ['анализ', 'референс', 'lab'])) return 'labs';
  if (_containsAny(lower, ['симптом', 'боль', 'самочув', 'symptom'])) {
    return 'symptoms';
  }
  if (_containsAny(lower, ['документ', 'врач', 'document', 'doctor'])) {
    return 'documents';
  }
  if (_containsAny(lower, ['сон', 'будил', 'sleep', 'alarm'])) return 'sleep';
  if (_containsAny(lower, ['командиров', 'поезд', 'trip', 'travel'])) {
    return 'trips';
  }
  if (_containsAny(lower, ['отпуск', 'vacation'])) return 'vacation';
  if (_containsAny(lower, ['климат', 'жар', 'холод', 'climate'])) {
    return 'climate';
  }
  return 'today';
}

bool _containsAny(String source, List<String> values) =>
    values.any(source.contains);
