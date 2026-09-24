import 'expanded_catalog.dart';
import 'health_plan_engine.dart';
import 'medical_knowledge.dart';
import 'model.dart';
import 'prescription_parser.dart';

class AssistantToolResult {
  const AssistantToolResult({
    required this.state,
    required this.message,
    required this.relatedSection,
  });

  final HealthAppState state;
  final String message;
  final String relatedSection;
}

class AssistantToolEngine {
  const AssistantToolEngine();

  AssistantToolResult? execute(HealthAppState state, String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return null;

    final water = RegExp(
      r'(?:выпил[а-яё]*|добав[а-яё]*|запиш[а-яё]*|water).*?(\d+(?:[\.,]\d+)?)\s*(мл|ml|л|l)(?![a-zа-яё])',
      caseSensitive: false,
    ).firstMatch(lower);
    if (water != null && (lower.contains('вод') || lower.contains('water'))) {
      var liters = _number(water.group(1));
      if (water.group(2)!.toLowerCase().contains('мл') ||
          water.group(2)!.toLowerCase() == 'ml') {
        liters /= 1000;
      }
      if (liters > 0 && liters <= 5) {
        final total = (state.today.waterLiters + liters)
            .clamp(0, 12)
            .toDouble();
        return AssistantToolResult(
          state: state.copyWith(
            today: state.today.copyWith(waterLiters: total),
          ),
          message:
              'Записал воду: +${liters.toStringAsFixed(liters < 1 ? 2 : 1)} л. '
              'Итого сегодня ${total.toStringAsFixed(2)} л.',
          relatedSection: 'nutrition',
        );
      }
    }

    final steps = RegExp(
      r'(?:добав[а-яё]*\s*)?(\d[\d\s]{1,7})\s*(?:шаг[а-яё]*|steps?)|(?:шаг[а-яё]*|steps?)\s*(\d[\d\s]{1,7})',
      caseSensitive: false,
    ).firstMatch(lower);
    if (steps != null) {
      final value = int.tryParse(
        (steps.group(1) ?? steps.group(2) ?? '').replaceAll(' ', ''),
      );
      if (value != null && value >= 0 && value <= 200000) {
        final additive = lower.contains('добав') || lower.contains('прош');
        final total = additive ? state.today.steps + value : value;
        return AssistantToolResult(
          state: state.copyWith(today: state.today.copyWith(steps: total)),
          message: additive
              ? 'Добавил $value шагов. Итого сегодня $total.'
              : 'Записал $total шагов за сегодня.',
          relatedSection: 'today',
        );
      }
    }

    final weight = RegExp(
      r'(?:вес|масса|weight)\s*(?:сегодня|now)?\s*[:=-]?\s*(\d{2,3}(?:[\.,]\d)?)\s*(?:кг|kg)?\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (weight != null) {
      final value = _number(weight.group(1));
      if (value >= 25 && value <= 350) {
        return AssistantToolResult(
          state: state.copyWith(
            profile: state.profile.copyWith(weightKg: value),
            today: state.today.copyWith(weightKg: value),
          ),
          message: 'Записал массу тела ${value.toStringAsFixed(1)} кг.',
          relatedSection: 'health',
        );
      }
    }

    final glucose = RegExp(
      r'(?:глюкоз[а-яё]*|сахар[а-яё]*\s+кров[а-яё]*|glucose)\s*[:=-]?\s*(\d{1,3}(?:[\.,]\d+)?)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (glucose != null) {
      var value = _number(glucose.group(1));
      var unit = 'ммоль/л';
      if (lower.contains('mg/dl') || lower.contains('мг/дл') || value > 35) {
        value /= 18.0182;
        unit = 'ммоль/л (пересчитано из мг/дл)';
      }
      if (value > 0.5 && value < 40) {
        final attention = value < 3.9 || value > 10;
        final item = LabResult(
          id: newId(),
          marker: 'Глюкоза крови',
          value: value.toStringAsFixed(1),
          unit: unit,
          reference: '3.9-10.0',
          date: state.today.date,
          needsAttention: attention,
          notes:
              'Внесено голосом или командой помощника; условия измерения не указаны.',
        );
        return AssistantToolResult(
          state: state.copyWith(labResults: [item, ...state.labResults]),
          message:
              'Записал глюкозу ${value.toStringAsFixed(1)} ммоль/л. '
              '${attention ? 'Значение отмечено для проверки; при плохом самочувствии действуйте по плану врача.' : 'Уточните в заметке, измерение было натощак или после еды.'}',
          relatedSection: 'labs',
        );
      }
    }

    final genericLab = _genericLabMatch(lower);
    if (genericLab != null) {
      final marker = _sentenceCase(genericLab.marker.trim());
      final normalizedValue = genericLab.value
          .replaceFirst(RegExp(r'^[<>]\s*'), '')
          .replaceAll(',', '.');
      final value = _number(normalizedValue);
      final reference = genericLab.reference.trim().replaceAll('–', '-');
      final bounds = RegExp(
        r'([<>]?)\s*(\d+(?:[\.,]\d+)?)\s*(?:[-–]\s*(\d+(?:[\.,]\d+)?))?',
      ).firstMatch(reference);
      final minimum = bounds == null || bounds.group(1) == '>'
          ? null
          : _number(bounds.group(2));
      final maximum = bounds?.group(3) == null
          ? bounds?.group(1) == '<'
                ? _number(bounds?.group(2))
                : null
          : _number(bounds?.group(3));
      final attention =
          (minimum != null && value < minimum) ||
          (maximum != null && value > maximum);
      final item = LabResult(
        id: newId(),
        marker: marker,
        value: normalizedValue,
        unit: genericLab.unit,
        reference: reference,
        date: state.today.date,
        needsAttention: attention,
        notes:
            'Внесено голосом или командой помощника; проверьте единицы и референс лаборатории.',
      );
      return AssistantToolResult(
        state: state.copyWith(labResults: [item, ...state.labResults]),
        message:
            'Записал анализ «$marker»: ${item.value} ${item.unit}'
            '${reference.isEmpty ? '' : ', референс $reference'}.'
            '${attention ? ' Значение отмечено для проверки врачом.' : ' Проверьте запись перед медицинской интерпретацией.'}',
        relatedSection: 'labs',
      );
    }

    final pressure = RegExp(
      r'(?:давлен[а-яё]*|pressure)\s*[:=-]?\s*(\d{2,3})\s*[/\\]\s*(\d{2,3})(?:\s+(?:пульс|pulse)\s*(\d{2,3}))?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (pressure != null) {
      final systolic = int.parse(pressure.group(1)!);
      final diastolic = int.parse(pressure.group(2)!);
      final pulse = int.tryParse(pressure.group(3) ?? '');
      if (systolic >= 60 &&
          systolic <= 260 &&
          diastolic >= 35 &&
          diastolic <= 180 &&
          (pulse == null || pulse >= 25 && pulse <= 240)) {
        final attention = systolic >= 180 || diastolic >= 120 || systolic < 90;
        final item = SymptomEntry(
          id: newId(),
          symptom: 'Артериальное давление',
          date: state.today.date,
          time: _clockNow(),
          intensity: attention ? 8 : 2,
          systolic: systolic,
          diastolic: diastolic,
          pulse: pulse,
          notes: 'Внесено командой помощника.',
          needsAttention: attention,
        );
        return AssistantToolResult(
          state: state.copyWith(
            symptomEntries: [item, ...state.symptomEntries],
          ),
          message:
              'Записал давление $systolic/$diastolic${pulse == null ? '' : ', пульс $pulse'}. '
              '${attention ? 'Показатель отмечен как тревожный. При симптомах или повторном высоком значении нужна срочная медицинская оценка.' : 'Для динамики измеряйте в покое и одинаковых условиях.'}',
          relatedSection: 'symptoms',
        );
      }
    }

    final temperature = RegExp(
      r'(?:температур[а-яё]*|temperature)\s*[:=-]?\s*(3[4-9]|4[0-2])(?:[\.,](\d))?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (temperature != null) {
      final value = double.parse(
        '${temperature.group(1)}.${temperature.group(2) ?? '0'}',
      );
      final attention = value >= 38;
      final item = SymptomEntry(
        id: newId(),
        symptom: 'Температура тела',
        date: state.today.date,
        time: _clockNow(),
        intensity: (value - 36).round().clamp(1, 10),
        temperatureC: value,
        notes: 'Внесено командой помощника.',
        needsAttention: attention,
      );
      return AssistantToolResult(
        state: state.copyWith(symptomEntries: [item, ...state.symptomEntries]),
        message:
            'Записал температуру ${value.toStringAsFixed(1)} °C. '
            '${attention ? 'Тренировку лучше отложить и следить за самочувствием.' : ''}',
        relatedSection: 'symptoms',
      );
    }

    final sleepRange = RegExp(
      r'(?:спал[а-яё]*|сон|sleep).*?(\d{1,2})[:\.](\d{2})\s*(?:до|[-–—])\s*(\d{1,2})[:\.](\d{2})',
      caseSensitive: false,
    ).firstMatch(lower);
    final sleepDuration = RegExp(
      r'(?:спал[а-яё]*|сон|sleep).*?(\d{1,2}(?:[\.,]\d+)?)\s*(?:ч(?:ас(?:а|ов)?)?|hours?|h)(?![a-zа-яё])',
      caseSensitive: false,
    ).firstMatch(lower);
    if (sleepRange != null || sleepDuration != null) {
      var bedTime = '';
      var wakeTime = '';
      var minutes = 0;
      if (sleepRange != null) {
        final bedHour = int.parse(sleepRange.group(1)!);
        final bedMinute = int.parse(sleepRange.group(2)!);
        final wakeHour = int.parse(sleepRange.group(3)!);
        final wakeMinute = int.parse(sleepRange.group(4)!);
        if (bedHour < 24 &&
            wakeHour < 24 &&
            bedMinute < 60 &&
            wakeMinute < 60) {
          final start = bedHour * 60 + bedMinute;
          var end = wakeHour * 60 + wakeMinute;
          if (end <= start) end += 24 * 60;
          minutes = end - start;
          bedTime =
              '${bedHour.toString().padLeft(2, '0')}:${bedMinute.toString().padLeft(2, '0')}';
          wakeTime =
              '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}';
        }
      } else {
        minutes = (_number(sleepDuration!.group(1)) * 60).round();
      }
      if (minutes >= 30 && minutes <= 24 * 60) {
        final qualityMatch = RegExp(
          r'(?:качеств[а-яё]*|оценк[а-яё]*)\s*(?:сна)?\s*[:=-]?\s*([1-5])',
          caseSensitive: false,
        ).firstMatch(lower);
        final quality = int.tryParse(qualityMatch?.group(1) ?? '') ?? 3;
        final record = SleepRecord(
          id: newId(),
          date: state.today.date,
          bedTime: bedTime,
          wakeTime: wakeTime,
          durationMinutes: minutes,
          quality: quality,
          source: 'assistant_voice',
          notes: 'Внесено голосом или командой помощника.',
        );
        final hours = minutes / 60;
        return AssistantToolResult(
          state: state.copyWith(
            today: state.today.copyWith(sleepHours: hours),
            sleepRecords: [record, ...state.sleepRecords],
          ),
          message:
              'Записал сон ${hours.toStringAsFixed(1)} ч${bedTime.isEmpty ? '' : ' ($bedTime-$wakeTime)'}, качество $quality/5.',
          relatedSection: 'sleep',
        );
      }
    }

    final symptom = RegExp(
      r'(?:запиш[а-яё]*|добав[а-яё]*|отмет[а-яё]*)\s+(?:симптом\s+)?(.+?)\s+(?:на\s+)?(10|[1-9])\s*(?:из|/|балл[а-яё]*)\s*10\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (symptom != null) {
      final title = _sentenceCase(symptom.group(1)!.trim());
      final intensity = int.parse(symptom.group(2)!);
      if (title.length >= 2 && title.length <= 80) {
        final item = SymptomEntry(
          id: newId(),
          symptom: title,
          date: state.today.date,
          time: _clockNow(),
          intensity: intensity,
          notes: 'Внесено голосом или командой помощника.',
          needsAttention: intensity >= 8,
        );
        return AssistantToolResult(
          state: state.copyWith(
            symptomEntries: [item, ...state.symptomEntries],
            today: state.today.copyWith(
              symptoms: [...state.today.symptoms, title],
            ),
          ),
          message:
              'Записал симптом «$title», интенсивность $intensity/10.${intensity >= 8 ? ' При резком ухудшении или опасных симптомах нужна срочная медицинская помощь.' : ''}',
          relatedSection: 'symptoms',
        );
      }
    }

    final meal = RegExp(
      r'(?:съел[а-яё]*|выпил[а-яё]*|запиш[а-яё]*\s+(?:еду|при[её]м пищи)|добав[а-яё]*\s+(?:еду|блюдо))\s+(.+?)\s+(\d{1,4})\s*(?:ккал|kcal)(?![a-zа-яё])',
      caseSensitive: false,
    ).firstMatch(lower);
    if (meal != null) {
      final title = _sentenceCase(meal.group(1)!.trim());
      final calories = int.parse(meal.group(2)!);
      final protein = _macroValue(lower, const ['белк', 'protein']);
      final fat = _macroValue(lower, const ['жир', 'fat']);
      final carbs = _macroValue(lower, const ['углевод', 'carb']);
      if (title.length >= 2 && title.length <= 100 && calories <= 5000) {
        final item = MealEntry(
          id: newId(),
          title: title,
          kind: 'Приём пищи',
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          confirmed: true,
          notes: 'Внесено голосом или командой помощника.',
          date: state.today.date,
          source: 'assistant_voice',
          time: _clockNow(),
        );
        return AssistantToolResult(
          state: state.copyWith(
            meals: [item, ...state.meals],
            today: state.today.copyWith(
              calories: state.today.calories + calories,
            ),
          ),
          message:
              'Записал «$title»: $calories ккал, Б/Ж/У $protein/$fat/$carbs г.',
          relatedSection: 'nutrition',
        );
      }
    }

    final alarm = RegExp(
      r'(?:будильник|разбуди|подъ[её]м).*?(?:в|на)?\s*((?:[01]?\d|2[0-3])[:\.]\d{2})',
      caseSensitive: false,
    ).firstMatch(lower);
    if (alarm != null &&
        (lower.contains('постав') ||
            lower.contains('созда') ||
            lower.contains('завед') ||
            lower.contains('будильник') ||
            lower.contains('разбуди'))) {
      final wakeTime = alarm.group(1)!.replaceAll('.', ':').padLeft(5, '0');
      final days = lower.contains('будн')
          ? 'пн, вт, ср, чт, пт'
          : lower.contains('выходн')
          ? 'сб, вс'
          : 'ежедневно';
      var title = query
          .replaceAll(
            RegExp(
              r'(?:поставь|создай|заведи|добавь|разбуди(?:\s+меня)?|будильник|подъ[её]м)',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\b(?:в|на)\s*\d{1,2}[:\.]\d{2}\b'), '')
          .trim();
      if (title.isEmpty || title.length > 80) title = 'Будильник';
      final item = AlarmGroup(
        id: newId(),
        title: _sentenceCase(title),
        wakeTime: wakeTime,
        bedTime: '',
        days: days,
        adaptive: lower.contains('умн') || lower.contains('цикл сна'),
        context: lower.contains('дежур')
            ? 'дежурство'
            : lower.contains('отпуск')
            ? 'отпуск'
            : 'обычный',
        priority: lower.contains('важн') || lower.contains('высок') ? 3 : 2,
        unlockMode: lower.contains('задач') || lower.contains('математ')
            ? 'math'
            : 'simple',
        dutyAware: lower.contains('дежур'),
        vacationAware: lower.contains('отпуск'),
        smartWakeWindowMinutes: lower.contains('цикл сна') ? 30 : 0,
        useWearableSleepCycle:
            lower.contains('браслет') || lower.contains('цикл сна'),
      );
      return AssistantToolResult(
        state: state.copyWith(alarmGroups: [item, ...state.alarmGroups]),
        message:
            'Создал будильник «${item.title}» на $wakeTime ($days). '
            '${item.unlockMode == 'math' ? 'Для отключения потребуется решить задачу.' : 'Обычное отключение.'}',
        relatedSection: 'calendar',
      );
    }

    final workoutMinutes = RegExp(
      r'(?:тренировк[а-яё]*|пробежал[а-яё]*|бегал[а-яё]*|занимал[а-яё]*).*?(\d{1,3})\s*(?:мин|минут)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (workoutMinutes != null &&
        (lower.contains('запиш') ||
            lower.contains('закончил') ||
            lower.contains('пров[её]л') ||
            lower.contains('пробеж') ||
            lower.contains('тренировал') ||
            lower.contains('занимал'))) {
      final minutes = int.parse(workoutMinutes.group(1)!);
      final distanceMatch = RegExp(
        r'(\d{1,3}(?:[\.,]\d+)?)\s*(?:км|km)',
        caseSensitive: false,
      ).firstMatch(lower);
      final calorieMatch = RegExp(
        r'(\d{2,4})\s*(?:ккал|kcal)',
        caseSensitive: false,
      ).firstMatch(lower);
      final distanceKm = _number(distanceMatch?.group(1));
      final calories =
          int.tryParse(calorieMatch?.group(1) ?? '') ??
          (minutes *
              (lower.contains('бег') || lower.contains('пробеж') ? 9 : 6));
      if (minutes > 0 && minutes <= 720 && distanceKm <= 200) {
        final title = lower.contains('бег') || lower.contains('пробеж')
            ? 'Бег'
            : lower.contains('ход')
            ? 'Ходьба'
            : 'Тренировка';
        final item = WorkoutSession(
          id: newId(),
          title: title,
          focus: 'Записано помощником',
          minutes: minutes,
          intensity: 'по факту',
          scheduledDate: state.today.date,
          exerciseIds: const [],
          notes: 'Внесено голосом или командой помощника.',
          mode: distanceKm > 0 ? 'geo-manual' : 'manual',
          distanceMeters: distanceKm * 1000,
          elapsedSeconds: minutes * 60,
          averageSpeedKmh: distanceKm <= 0 ? 0 : distanceKm / (minutes / 60),
          caloriesBurned: calories.clamp(0, 10000),
          status: 'completed',
          completedAt: DateTime.now().toIso8601String(),
        );
        return AssistantToolResult(
          state: state.copyWith(
            workouts: [item, ...state.workouts],
            today: state.today.copyWith(
              workoutMinutes: state.today.workoutMinutes + minutes,
              activeCalories: state.today.activeCalories + item.caloriesBurned,
            ),
          ),
          message:
              'Записал: $title, $minutes мин, ${item.caloriesBurned} ккал'
              '${distanceKm > 0 ? ', ${distanceKm.toStringAsFixed(2)} км' : ''}.',
          relatedSection: 'workouts',
        );
      }
    }

    final activity = RegExp(
      r'(?:запиш[а-яё]*|добав[а-яё]*|был[а-яё]*\s+актив[а-яё]*|активност[а-яё]*)\s*(?:активност[а-яё]*)?.*?(\d{1,3})\s*(?:мин|минут)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (activity != null &&
        (lower.contains('актив') || lower.contains('размин'))) {
      final minutes = int.parse(activity.group(1)!);
      if (minutes > 0 && minutes <= 720) {
        final calories = (minutes * 4).clamp(0, 5000);
        final item = WorkoutSession(
          id: newId(),
          title: lower.contains('размин') ? 'Разминка' : 'Активность',
          focus: 'Повседневная активность',
          minutes: minutes,
          intensity: 'по факту',
          scheduledDate: state.today.date,
          exerciseIds: const [],
          notes:
              'Внесено голосом или командой помощника; расход калорий является оценкой.',
          mode: 'manual-activity',
          elapsedSeconds: minutes * 60,
          caloriesBurned: calories,
          status: 'completed',
          completedAt: DateTime.now().toIso8601String(),
        );
        return AssistantToolResult(
          state: state.copyWith(
            workouts: [item, ...state.workouts],
            today: state.today.copyWith(
              workoutMinutes: state.today.workoutMinutes + minutes,
              activeCalories: state.today.activeCalories + calories,
            ),
          ),
          message:
              'Записал активность: $minutes мин, ориентировочный расход $calories ккал.',
          relatedSection: 'workouts',
        );
      }
    }

    final reminder = RegExp(
      r'(?:напомни|напоминание|remind).*?(\d{1,2})[:\.](\d{2})',
      caseSensitive: false,
    ).firstMatch(lower);
    if (reminder != null) {
      final hour = int.parse(reminder.group(1)!);
      final minute = int.parse(reminder.group(2)!);
      if (hour < 24 && minute < 60) {
        final time =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        var title = query
            .replaceFirst(
              RegExp(r'напомни(?:\s+мне)?', caseSensitive: false),
              '',
            )
            .replaceFirst(RegExp(r'напоминание', caseSensitive: false), '')
            .replaceFirst(RegExp(r'\b(?:в|на)\s*\d{1,2}[:\.]\d{2}\b'), '')
            .trim();
        if (title.isEmpty) title = 'Напоминание';
        final item = ReminderItem(
          id: newId(),
          title: title,
          time: time,
          category: 'помощник',
          done: false,
          date: state.today.date,
        );
        return AssistantToolResult(
          state: state.copyWith(reminders: [item, ...state.reminders]),
          message: 'Создал напоминание «$title» на $time сегодня.',
          relatedSection: 'calendar',
        );
      }
    }

    if ((lower.contains('назнач') ||
            lower.contains('рецепт') ||
            lower.contains('принимать') ||
            lower.contains('приём') ||
            lower.contains('прием')) &&
        RegExp(
          r'\d+(?:[\.,]\d+)?\s*(?:мкг|мг|г|мл|ед\.?|ме)',
          caseSensitive: false,
        ).hasMatch(lower)) {
      final prescriptionText = query
          .replaceFirst(
            RegExp(
              r'^(?:врач\s+)?(?:мне\s+)?(?:назначил(?:а|и)?|назначение|рецепт|принимать)\s*[:\-]?\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      final drafts = parsePrescriptionText(prescriptionText);
      if (drafts.isNotEmpty) {
        final candidates = [
          for (final draft in drafts)
            RecognitionCandidate(
              id: newId(),
              source: 'голосовое назначение',
              title:
                  '${draft.name}${draft.dose.isEmpty ? '' : ' · ${draft.dose}'}',
              confidence: draft.confidence,
              requiresMedicalReview: true,
              kind: 'voice-prescription',
              createdAt: todayKey(),
              metadata: draft.toMetadata(),
            ),
        ];
        return AssistantToolResult(
          state: state.copyWith(
            confirmationQueue: [...candidates, ...state.confirmationQueue],
          ),
          message:
              'Распознал назначений: ${candidates.length}. Добавил их на проверку; после подтверждения приложение создаст расписание и напоминания. Дозировки автоматически не меняются.',
          relatedSection: 'medicines',
        );
      }
    }

    if (lower.contains('принял') || lower.contains('приняла')) {
      final matches = state.medications.where(
        (item) => lower.contains(item.name.toLowerCase()),
      );
      if (matches.length == 1) {
        final medicine = matches.first;
        final intake = MedicationIntake(
          id: newId(),
          medicationId: medicine.id,
          medicationName: medicine.name,
          dose: medicine.dose,
          date: state.today.date,
          time: _clockNow(),
          status: 'принято',
          notes: 'Отмечено командой помощника.',
        );
        final alreadyTaken = state.medicationIntakes.any(
          (item) =>
              item.medicationId == medicine.id &&
              item.date == state.today.date &&
              item.status == 'принято',
        );
        final medicines = state.medications
            .map(
              (item) => item.id == medicine.id
                  ? item.copyWith(
                      takenToday: true,
                      remainingUnits: alreadyTaken || item.remainingUnits <= 0
                          ? item.remainingUnits
                          : item.remainingUnits - 1,
                    )
                  : item,
            )
            .toList();
        return AssistantToolResult(
          state: state.copyWith(
            medications: medicines,
            medicationIntakes: [intake, ...state.medicationIntakes],
          ),
          message:
              'Отметил приём «${medicine.name}» (${medicine.dose}). Дозировку я не изменяю.',
          relatedSection: 'medicines',
        );
      }
    }
    return null;
  }
}

({String marker, String value, String unit, String reference})?
_genericLabMatch(String source) {
  const unit =
      r'(ммоль/л|мкмоль/л|мг/дл|мг/л|г/л|г/дл|мкг/л|нг/мл|пг/мл|мед/л|ме/л|ед/л|%|mmol/l|umol/l|µmol/l|mg/dl|mg/l|g/l|g/dl|µg/l|ug/l|ng/ml|pg/ml|iu/l|u/l)';
  final prefixed = RegExp(
    r'(?:анализ|показатель|результат(?:\s+анализа)?)\s+([a-zа-яё][a-zа-яё0-9 ()+._-]{1,60}?)\s*[:=-]?\s*([<>]?\s*\d+(?:[\.,]\d+)?)\s*' +
        unit +
        r'(?:.*?(?:референс|норма)\s*[:=-]?\s*([<>]?\s*\d+(?:[\.,]\d+)?(?:\s*[-–]\s*\d+(?:[\.,]\d+)?)?))?',
    caseSensitive: false,
  ).firstMatch(source);
  final known =
      prefixed ??
      RegExp(
        r'\b(гемоглобин|ферритин|холестерин|триглицериды|креатинин|мочевина|билирубин|алт|аст|ттг|витамин\s+[a-zа-яё0-9]+|с-?реактивный\s+белок)\s*[:=-]?\s*([<>]?\s*\d+(?:[\.,]\d+)?)\s*' +
            unit +
            r'(?:.*?(?:референс|норма)\s*[:=-]?\s*([<>]?\s*\d+(?:[\.,]\d+)?(?:\s*[-–]\s*\d+(?:[\.,]\d+)?)?))?',
        caseSensitive: false,
      ).firstMatch(source);
  if (known == null) return null;
  final marker = known.group(1)?.trim() ?? '';
  final value = (known.group(2) ?? '').replaceAll(' ', '');
  final parsedUnit = known.group(3)?.trim() ?? '';
  final reference = known.group(4)?.trim() ?? '';
  final numeric = _number(value.replaceFirst(RegExp(r'^[<>]\s*'), ''));
  if (marker.length < 2 || numeric <= 0 || numeric > 1000000) return null;
  return (marker: marker, value: value, unit: parsedUnit, reference: reference);
}

Future<String> buildLocalAssistantContext(
  HealthAppState state,
  String query, {
  String activityContext = '',
}) async {
  final plan = buildIntegratedHealthPlan(state);
  final lines = <String>[
    'Дата: ${state.today.date}.',
    'Профиль: возраст ${state.profile.age}, пол ${state.profile.gender}, ИМТ ${state.profile.bmi.toStringAsFixed(1)}, цель ${state.profile.goal}.',
    'Сегодня: сон ${state.today.sleepHours.toStringAsFixed(1)} ч, вода ${state.today.waterLiters.toStringAsFixed(1)} л, шаги ${state.today.steps}, питание ${state.today.calories} ккал, активность ${state.today.workoutMinutes} мин.',
    'Готовность ${state.readinessScore}/100, энергия ${state.energyScore}/100.',
    if (state.chronicConditions.isNotEmpty)
      'Состояния: ${state.chronicConditions.join(', ')}.',
    if (state.allergies.isNotEmpty) 'Аллергии: ${state.allergies.join(', ')}.',
    if (state.contraindications.isNotEmpty)
      'Ограничения: ${state.contraindications.join(', ')}.',
    if (state.medications.isNotEmpty)
      'Назначенные препараты: ${state.medications.map((item) => '${item.name} ${item.dose}; ${item.schedule}').join(' | ')}.',
    if (state.symptomEntries.isNotEmpty)
      'Последние симптомы: ${state.symptomEntries.take(5).map((item) => '${item.symptom} ${item.intensity}/10').join(', ')}.',
    if (activityContext.isNotEmpty) 'Контекст телефона: $activityContext.',
    'Связанный план на день: ${plan.summary}',
    if (plan.recommendations.isNotEmpty)
      'Рекомендации плана: ${plan.recommendations.take(6).map((item) => '${item.title}: ${item.detail}').join(' | ')}.',
  ];

  final lower = query.toLowerCase();
  final words = lower
      .split(RegExp(r'[^a-zа-яё0-9]+', caseSensitive: false))
      .where((word) => word.length >= 3 && !_stopWords.contains(word))
      .toSet();
  if (_containsAny(lower, const [
    'ед',
    'блюд',
    'продукт',
    'питан',
    'калор',
    'белок',
    'рецепт',
  ])) {
    final foods = await ExpandedCatalogRepository.instance.foods();
    final matches = foods
        .where((item) {
          final haystack =
              '${item.titleRu} ${item.titleEn} ${item.category} ${item.categoryRu} ${item.composition} ${item.compositionRu}'
                  .toLowerCase();
          return words.any(haystack.contains);
        })
        .take(5);
    if (matches.isNotEmpty) {
      lines.add(
        'Найдено в локальном каталоге еды: ${matches.map((item) => '${item.titleFor(state.localeCode)}: ${item.calories} ккал, Б/Ж/У ${item.protein}/${item.fat}/${item.carbs}, полезность ${item.healthLevel}/10; ${item.doctorReview}').join(' | ')}.',
      );
    }
  }
  if (_containsAny(lower, const ['трен', 'упраж', 'спорт', 'мышц', 'бег'])) {
    final workouts = await ExpandedCatalogRepository.instance.workouts();
    final matches = workouts
        .where((item) {
          final haystack =
              '${item.titleRu} ${item.titleEn} ${item.focus} ${item.focusRu} ${item.equipment} ${item.equipmentRu}'
                  .toLowerCase();
          return words.any(haystack.contains);
        })
        .take(5);
    if (matches.isNotEmpty) {
      lines.add(
        'Найдено в локальном каталоге тренировок: ${matches.map((item) => '${item.titleFor(state.localeCode)}: ${item.focusFor(state.localeCode)}, ${item.minutes} мин, ${item.calories} ккал; предупреждения: ${item.warningsFor(state.localeCode)}').join(' | ')}.',
      );
    }
  }
  final medical = await MedicalKnowledgeRepository.instance.load();
  final topicMatches = medical.topics
      .where((item) => words.any(item.searchText.contains))
      .take(4)
      .toList();
  if (topicMatches.isNotEmpty) {
    lines.add(
      'Найдено в локальном медицинском справочнике: ${topicMatches.map((item) => '${item.titleRu.isEmpty ? item.titleEn : item.titleRu}: ${item.summary}${item.urgent.isEmpty ? '' : ' Срочно: ${item.urgent}'}').join(' | ')}.',
    );
  }
  final substanceMatches = medical.substances
      .where((item) => words.any(item.searchText.contains))
      .take(4)
      .toList();
  if (substanceMatches.isNotEmpty) {
    lines.add(
      'Найдено в локальной базе лекарств и витаминов: ${substanceMatches.map((item) => '${item.title}: ${item.purpose} Предупреждение: ${item.warnings} Взаимодействия: ${item.interactions}').join(' | ')}.',
    );
  }
  return lines.join('\n');
}

double _number(String? value) =>
    double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0;

int _macroValue(String source, List<String> stems) {
  for (final stem in stems) {
    final match = RegExp(
      '$stem[a-zа-яё]*\\s*[:=-]?\\s*(\\d{1,3}(?:[\\.,]\\d+)?)\\s*(?:г|g)?',
      caseSensitive: false,
    ).firstMatch(source);
    if (match != null) return _number(match.group(1)).round().clamp(0, 500);
  }
  return 0;
}

String _sentenceCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _clockNow() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

bool _containsAny(String source, List<String> values) =>
    values.any(source.contains);

const _stopWords = <String>{
  'что',
  'как',
  'для',
  'это',
  'мне',
  'можно',
  'нужно',
  'сегодня',
  'подскажи',
  'the',
  'and',
  'with',
};
