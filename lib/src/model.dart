import 'dart:math' as math;

String todayKey([DateTime? value]) {
  final date = value ?? DateTime.now();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? parseDateKey(String value) {
  final trimmed = value.trim();
  final parts = trimmed.contains('.')
      ? trimmed.split('.').reversed.toList()
      : trimmed.split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

String displayDateKey(String value) {
  final date = parseDateKey(value);
  if (date == null) {
    return value;
  }
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String normalizeDateKey(String value, {String fallback = ''}) {
  final date = parseDateKey(value);
  if (date == null) {
    return fallback.isEmpty ? value.trim() : fallback;
  }
  return todayKey(date);
}

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class HealthAppState {
  const HealthAppState({
    required this.onboardingComplete,
    required this.localeCode,
    required this.profile,
    required this.settings,
    required this.today,
    required this.dailyHistory,
    required this.chronicConditions,
    required this.allergies,
    required this.contraindications,
    required this.inventory,
    required this.medications,
    required this.medicationIntakes,
    required this.labResults,
    required this.meals,
    required this.workouts,
    required this.alarmGroups,
    required this.trips,
    required this.devices,
    required this.documents,
    required this.reminders,
    required this.confirmationQueue,
    required this.symptomNotes,
    required this.symptomEntries,
    required this.sleepRecords,
    required this.customOptions,
    required this.careProviders,
    required this.medicalEvents,
    required this.injuries,
    required this.workSchedule,
    required this.activityReminders,
    required this.offlineMapPacks,
    required this.assistantMessages,
  });

  final bool onboardingComplete;
  final String localeCode;
  final UserProfile profile;
  final AppSettings settings;
  final DailyMetrics today;
  final List<DailyMetrics> dailyHistory;
  final List<String> chronicConditions;
  final List<String> allergies;
  final List<String> contraindications;
  final List<String> inventory;
  final List<Medication> medications;
  final List<MedicationIntake> medicationIntakes;
  final List<LabResult> labResults;
  final List<MealEntry> meals;
  final List<WorkoutSession> workouts;
  final List<AlarmGroup> alarmGroups;
  final List<TripPlan> trips;
  final List<DeviceConnection> devices;
  final List<HealthDocument> documents;
  final List<ReminderItem> reminders;
  final List<RecognitionCandidate> confirmationQueue;
  final List<String> symptomNotes;
  final List<SymptomEntry> symptomEntries;
  final List<SleepRecord> sleepRecords;
  final List<CustomOption> customOptions;
  final List<CareProvider> careProviders;
  final List<MedicalEvent> medicalEvents;
  final List<MedicalEvent> injuries;
  final WorkSchedule workSchedule;
  final ActivityReminderSettings activityReminders;
  final List<OfflineMapPack> offlineMapPacks;
  final List<AssistantMessage> assistantMessages;

  factory HealthAppState.seed() {
    final date = todayKey();
    final today = DailyMetrics.empty(date);
    return HealthAppState(
      onboardingComplete: false,
      localeCode: 'ru',
      profile: const UserProfile(
        name: '',
        birthDate: '',
        heightCm: 0,
        weightKg: 0,
        country: '',
        city: '',
        climate: '',
        climateSummer: '',
        climateWinter: '',
        latitude: null,
        longitude: null,
        solarPhenomena: [],
        goal: '',
        trainingGoals: [],
        activityLevel: '',
        gender: '',
      ),
      settings: const AppSettings(),
      today: today,
      dailyHistory: [today],
      chronicConditions: const [],
      allergies: const [],
      contraindications: const [],
      inventory: const [],
      medications: const [],
      medicationIntakes: const [],
      labResults: const [],
      meals: const [],
      workouts: const [],
      alarmGroups: const [],
      trips: const [],
      devices: const [],
      documents: const [],
      reminders: const [],
      confirmationQueue: const [],
      symptomNotes: const [],
      symptomEntries: const [],
      sleepRecords: const [],
      customOptions: const [],
      careProviders: const [],
      medicalEvents: const [],
      injuries: const [],
      workSchedule: const WorkSchedule(),
      activityReminders: const ActivityReminderSettings(),
      offlineMapPacks: const [],
      assistantMessages: const [],
    );
  }

  factory HealthAppState.fromJson(Map<String, dynamic> json) {
    final seed = HealthAppState.seed();
    final today = DailyMetrics.fromJson(_map(json['today']), seed.today);
    final history = _objectList(
      json['dailyHistory'],
      DailyMetrics.fromJsonSafe,
    );
    final mergedHistory = _upsertDailyMetric(
      history.isEmpty ? [today] : history,
      today,
    );
    final medications = _objectList(json['medications'], Medication.fromJson);
    final savedIntakes = _objectList(
      json['medicationIntakes'],
      MedicationIntake.fromJson,
    );
    final medicationIntakes = savedIntakes.isEmpty
        ? medications
              .where((item) => item.takenToday)
              .map(
                (item) => MedicationIntake(
                  id: newId(),
                  medicationId: item.id,
                  medicationName: item.name,
                  dose: item.dose,
                  date: today.date,
                  time: '',
                  status: 'принято',
                  notes: 'Перенесено из прежней отметки takenToday.',
                ),
              )
              .toList()
        : savedIntakes;
    return HealthAppState(
      onboardingComplete: _bool(
        json['onboardingComplete'],
        seed.onboardingComplete,
      ),
      localeCode: _string(json['localeCode'], seed.localeCode),
      profile: UserProfile.fromJson(_map(json['profile']), seed.profile),
      settings: AppSettings.fromJson(_map(json['settings']), seed.settings),
      today: today,
      dailyHistory: mergedHistory,
      chronicConditions: _stringList(
        json['chronicConditions'],
        seed.chronicConditions,
      ),
      allergies: _stringList(json['allergies'], seed.allergies),
      contraindications: _stringList(
        json['contraindications'],
        seed.contraindications,
      ),
      inventory: _stringList(json['inventory'], seed.inventory),
      medications: medications,
      medicationIntakes: medicationIntakes,
      labResults: _objectList(json['labResults'], LabResult.fromJson),
      meals: _objectList(json['meals'], MealEntry.fromJson),
      workouts: _objectList(json['workouts'], WorkoutSession.fromJson),
      alarmGroups: _objectList(json['alarmGroups'], AlarmGroup.fromJson),
      trips: _objectList(json['trips'], TripPlan.fromJson),
      devices: _objectList(json['devices'], DeviceConnection.fromJson),
      documents: _objectList(json['documents'], HealthDocument.fromJson),
      reminders: _objectList(json['reminders'], ReminderItem.fromJson),
      confirmationQueue: _objectList(
        json['confirmationQueue'],
        RecognitionCandidate.fromJson,
      ),
      symptomNotes: _stringList(json['symptomNotes'], seed.symptomNotes),
      symptomEntries: _objectList(
        json['symptomEntries'],
        SymptomEntry.fromJson,
      ),
      sleepRecords: _objectList(json['sleepRecords'], SleepRecord.fromJson),
      customOptions: _objectList(json['customOptions'], CustomOption.fromJson),
      careProviders: _objectList(json['careProviders'], CareProvider.fromJson),
      medicalEvents: _objectList(json['medicalEvents'], MedicalEvent.fromJson),
      injuries: _objectList(json['injuries'], MedicalEvent.fromJson),
      workSchedule: WorkSchedule.fromJson(
        _map(json['workSchedule']),
        seed.workSchedule,
      ),
      activityReminders: ActivityReminderSettings.fromJson(
        _map(json['activityReminders']),
        seed.activityReminders,
      ),
      offlineMapPacks: _objectList(
        json['offlineMapPacks'],
        OfflineMapPack.fromJson,
      ),
      assistantMessages: _objectList(
        json['assistantMessages'],
        AssistantMessage.fromJson,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': 8,
    'onboardingComplete': onboardingComplete,
    'localeCode': localeCode,
    'profile': profile.toJson(),
    'settings': settings.toJson(),
    'today': today.toJson(),
    'dailyHistory': dailyHistory.map((item) => item.toJson()).toList(),
    'chronicConditions': chronicConditions,
    'allergies': allergies,
    'contraindications': contraindications,
    'inventory': inventory,
    'medications': medications.map((item) => item.toJson()).toList(),
    'medicationIntakes': medicationIntakes
        .map((item) => item.toJson())
        .toList(),
    'labResults': labResults.map((item) => item.toJson()).toList(),
    'meals': meals.map((item) => item.toJson()).toList(),
    'workouts': workouts.map((item) => item.toJson()).toList(),
    'alarmGroups': alarmGroups.map((item) => item.toJson()).toList(),
    'trips': trips.map((item) => item.toJson()).toList(),
    'devices': devices.map((item) => item.toJson()).toList(),
    'documents': documents.map((item) => item.toJson()).toList(),
    'reminders': reminders.map((item) => item.toJson()).toList(),
    'confirmationQueue': confirmationQueue
        .map((item) => item.toJson())
        .toList(),
    'symptomNotes': symptomNotes,
    'symptomEntries': symptomEntries.map((item) => item.toJson()).toList(),
    'sleepRecords': sleepRecords.map((item) => item.toJson()).toList(),
    'customOptions': customOptions.map((item) => item.toJson()).toList(),
    'careProviders': careProviders.map((item) => item.toJson()).toList(),
    'medicalEvents': medicalEvents.map((item) => item.toJson()).toList(),
    'injuries': injuries.map((item) => item.toJson()).toList(),
    'workSchedule': workSchedule.toJson(),
    'activityReminders': activityReminders.toJson(),
    'offlineMapPacks': offlineMapPacks.map((item) => item.toJson()).toList(),
    'assistantMessages': assistantMessages
        .map((item) => item.toJson())
        .toList(),
  };

  HealthAppState copyWith({
    bool? onboardingComplete,
    String? localeCode,
    UserProfile? profile,
    AppSettings? settings,
    DailyMetrics? today,
    List<DailyMetrics>? dailyHistory,
    List<String>? chronicConditions,
    List<String>? allergies,
    List<String>? contraindications,
    List<String>? inventory,
    List<Medication>? medications,
    List<MedicationIntake>? medicationIntakes,
    List<LabResult>? labResults,
    List<MealEntry>? meals,
    List<WorkoutSession>? workouts,
    List<AlarmGroup>? alarmGroups,
    List<TripPlan>? trips,
    List<DeviceConnection>? devices,
    List<HealthDocument>? documents,
    List<ReminderItem>? reminders,
    List<RecognitionCandidate>? confirmationQueue,
    List<String>? symptomNotes,
    List<SymptomEntry>? symptomEntries,
    List<SleepRecord>? sleepRecords,
    List<CustomOption>? customOptions,
    List<CareProvider>? careProviders,
    List<MedicalEvent>? medicalEvents,
    List<MedicalEvent>? injuries,
    WorkSchedule? workSchedule,
    ActivityReminderSettings? activityReminders,
    List<OfflineMapPack>? offlineMapPacks,
    List<AssistantMessage>? assistantMessages,
  }) {
    final nextToday = today ?? this.today;
    return HealthAppState(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      localeCode: localeCode ?? this.localeCode,
      profile: profile ?? this.profile,
      settings: settings ?? this.settings,
      today: nextToday,
      dailyHistory:
          dailyHistory ?? _upsertDailyMetric(this.dailyHistory, nextToday),
      chronicConditions: chronicConditions ?? this.chronicConditions,
      allergies: allergies ?? this.allergies,
      contraindications: contraindications ?? this.contraindications,
      inventory: inventory ?? this.inventory,
      medications: medications ?? this.medications,
      medicationIntakes: medicationIntakes ?? this.medicationIntakes,
      labResults: labResults ?? this.labResults,
      meals: meals ?? this.meals,
      workouts: workouts ?? this.workouts,
      alarmGroups: alarmGroups ?? this.alarmGroups,
      trips: trips ?? this.trips,
      devices: devices ?? this.devices,
      documents: documents ?? this.documents,
      reminders: reminders ?? this.reminders,
      confirmationQueue: confirmationQueue ?? this.confirmationQueue,
      symptomNotes: symptomNotes ?? this.symptomNotes,
      symptomEntries: symptomEntries ?? this.symptomEntries,
      sleepRecords: sleepRecords ?? this.sleepRecords,
      customOptions: customOptions ?? this.customOptions,
      careProviders: careProviders ?? this.careProviders,
      medicalEvents: medicalEvents ?? this.medicalEvents,
      injuries: injuries ?? this.injuries,
      workSchedule: workSchedule ?? this.workSchedule,
      activityReminders: activityReminders ?? this.activityReminders,
      offlineMapPacks: offlineMapPacks ?? this.offlineMapPacks,
      assistantMessages: assistantMessages ?? this.assistantMessages,
    );
  }

  DailyMetrics metricsFor(String date) {
    return dailyHistory.firstWhere(
      (item) => item.date == date,
      orElse: () => today.date == date ? today : DailyMetrics.empty(date),
    );
  }

  HealthAppState updateMetricsFor(String date, DailyMetrics metrics) {
    final normalized = metrics.copyWith(date: date);
    return copyWith(
      today: date == today.date ? normalized : today,
      dailyHistory: _upsertDailyMetric(dailyHistory, normalized),
    );
  }

  List<MedicationIntake> medicationIntakesFor(String date) {
    return medicationIntakes.where((item) => item.date == date).toList();
  }

  bool medicationTakenOnDate(Medication medication, String date) {
    return medicationIntakes.any(
      (item) =>
          item.date == date &&
          (item.medicationId == medication.id ||
              item.medicationName == medication.name) &&
          item.status == 'принято',
    );
  }

  int medicationTakenCount(String date) {
    return medications
        .where((item) => medicationTakenOnDate(item, date))
        .length;
  }

  List<String> customLabels(String group) {
    return customOptions
        .where((item) => item.group == group)
        .map((item) => item.label)
        .toList();
  }

  int get readinessScore {
    final sleep = _bounded(today.sleepHours / 8.0);
    final activity = _bounded(today.steps / 9000.0);
    final hydration = _bounded(today.waterLiters / 2.4);
    final mood = _bounded(today.mood / 5.0);
    final stressPenalty = _bounded(today.stress / 5.0) * 12;
    return ((sleep * 34) +
            (activity * 25) +
            (hydration * 20) +
            (mood * 21) -
            stressPenalty)
        .round()
        .clamp(0, 100);
  }

  int get energyScore {
    final nutrition = _bounded(today.calories / 2100.0);
    final movement = _bounded(today.workoutMinutes / 45.0);
    final sleep = _bounded(today.sleepHours / 8.0);
    return ((nutrition * 28) +
            (movement * 22) +
            (sleep * 35) +
            (today.mood * 3))
        .round()
        .clamp(0, 100);
  }

  int get openSafetyItems =>
      confirmationQueue.where((item) => item.requiresMedicalReview).length +
      labResults.where((item) => item.needsAttention).length;

  List<String> get insights {
    final result = <String>[];
    if (today.sleepHours > 0 && today.sleepHours < 6.5) {
      result.add('Сон ниже цели: сегодня лучше выбрать лёгкую тренировку.');
    }
    if (today.waterLiters > 0 && today.waterLiters < 2.0) {
      result.add(
        'Вода отстаёт от плана: добавьте 2 небольших стакана до вечера.',
      );
    }
    if (today.steps >= 8000) {
      result.add('Активность хорошая: шаги уже закрывают базовую цель дня.');
    }
    if (medications.isNotEmpty &&
        medicationTakenCount(today.date) < medications.length) {
      result.add('Есть незакрытые лекарства: проверьте расписание приёма.');
    }
    if (openSafetyItems > 0) {
      result.add(
        'Есть данные, требующие ручного подтверждения и спокойной проверки.',
      );
    }
    if (profile.solarPhenomena.isNotEmpty) {
      result.add(
        'Локация: ${profile.solarPhenomena.join(', ')}. Учитывайте световой режим при сне.',
      );
    }
    if (result.isEmpty) {
      result.add(
        'Добавьте первые данные дня, и приложение рассчитает рекомендации.',
      );
    }
    return result;
  }

  String get motivationMessage {
    final unsafe =
        readinessScore < 35 ||
        symptomEntries.any(
          (item) =>
              item.needsAttention ||
              item.intensity >= 8 ||
              (item.temperatureC ?? 0) >= 38,
        ) ||
        workouts.any(
          (item) =>
              item.scheduledDate == today.date &&
              item.exerciseResults.any((result) => result.pain),
        );
    if (unsafe) {
      return 'Сегодня важнее восстановление. Не тренируйтесь через боль, температуру или резкое ухудшение самочувствия.';
    }
    final completed = workouts.any(
      (item) => item.scheduledDate == today.date && item.status == 'completed',
    );
    if (completed) {
      return 'Тренировка уже выполнена. Отметьте воду, питание и дайте организму восстановиться.';
    }
    final missed = workouts
        .where(
          (item) =>
              item.status == 'missed' ||
              item.status == 'planned' &&
                  item.scheduledDate.compareTo(today.date) < 0,
        )
        .length;
    return switch (settings.motivationStrictness.clamp(1, 4)) {
      1 => 'Даже 10 минут прогулки или мягкой разминки сегодня засчитаются.',
      2 =>
        'Тренировка запланирована на сегодня. Выберите полную или короткую версию по самочувствию.',
      3 =>
        missed > 0
            ? 'План уже переносился. Выполните хотя бы безопасную короткую тренировку на 15 минут.'
            : 'Не откладывайте план без причины: начните с разминки и оцените самочувствие.',
      _ =>
        missed > 0
            ? 'Хватит откладывать: включайте короткую тренировку на 15 минут. При боли или недомогании остановитесь.'
            : 'Начинайте запланированную тренировку сейчас. Снизить нагрузку можно, пропускать без причины не стоит.',
    };
  }
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    required this.country,
    required this.city,
    required this.climate,
    required this.climateSummer,
    required this.climateWinter,
    required this.latitude,
    required this.longitude,
    required this.solarPhenomena,
    required this.goal,
    required this.trainingGoals,
    required this.activityLevel,
    required this.gender,
    this.favoriteFoods = const [],
    this.dislikedFoods = const [],
    this.dietType = 'обычное питание',
    this.foodBudget = 'средний',
    this.maxCookingMinutes = 45,
    this.recipeLanguage = 'system',
    this.workoutLanguage = 'system',
    this.timeZone = '',
    this.typicalTemperatureC = 0,
    this.humidityPercent = 0,
    this.altitudeMeters = 0,
    this.airQuality = '',
    this.regionalAllergens = const [],
    this.climateReactions = const [],
    this.homeLatitude,
    this.homeLongitude,
    this.workLatitude,
    this.workLongitude,
    this.placeRadiusMeters = 200,
  });

  final String name;
  final String birthDate;
  final double heightCm;
  final double weightKg;
  final String country;
  final String city;
  final String climate;
  final String climateSummer;
  final String climateWinter;
  final double? latitude;
  final double? longitude;
  final List<String> solarPhenomena;
  final String goal;
  final List<String> trainingGoals;
  final String activityLevel;
  final String gender;
  final List<String> favoriteFoods;
  final List<String> dislikedFoods;
  final String dietType;
  final String foodBudget;
  final int maxCookingMinutes;
  final String recipeLanguage;
  final String workoutLanguage;
  final String timeZone;
  final double typicalTemperatureC;
  final int humidityPercent;
  final int altitudeMeters;
  final String airQuality;
  final List<String> regionalAllergens;
  final List<String> climateReactions;
  final double? homeLatitude;
  final double? homeLongitude;
  final double? workLatitude;
  final double? workLongitude;
  final int placeRadiusMeters;

  int get age {
    final birth = parseDateKey(birthDate);
    if (birth == null) {
      return 0;
    }
    final now = DateTime.now();
    var value = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      value--;
    }
    return math.max(0, value);
  }

  double get bmi {
    if (heightCm <= 0 || weightKg <= 0) {
      return 0;
    }
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  double get estimatedBodyFatPercent {
    final valueBmi = bmi;
    if (valueBmi <= 0 || age <= 0) {
      return 0;
    }
    final sexFactor =
        gender.toLowerCase().contains('муж') ||
            gender.toLowerCase().contains('male') ||
            gender.toLowerCase().contains('man')
        ? 1
        : 0;
    return (1.2 * valueBmi + 0.23 * age - 10.8 * sexFactor - 5.4)
        .clamp(2, 65)
        .toDouble();
  }

  double get basalMetabolicRate {
    if (heightCm <= 0 || weightKg <= 0 || age <= 0) {
      return 0;
    }
    final sexOffset =
        gender.toLowerCase().contains('муж') ||
            gender.toLowerCase().contains('male') ||
            gender.toLowerCase().contains('man')
        ? 5
        : -161;
    return 10 * weightKg + 6.25 * heightCm - 5 * age + sexOffset;
  }

  int restingCaloriesBurnedSoFar([DateTime? now]) {
    final bmr = basalMetabolicRate;
    if (bmr <= 0) {
      return 0;
    }
    final moment = now ?? DateTime.now();
    final seconds = moment.hour * 3600 + moment.minute * 60 + moment.second;
    return (bmr * seconds / 86400).round().clamp(0, bmr.round()).toInt();
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json,
    UserProfile fallback,
  ) {
    final legacyAge = _int(json['age'], 0);
    final legacyBirthDate = legacyAge > 0
        ? '${DateTime.now().year - legacyAge}-01-01'
        : fallback.birthDate;
    return UserProfile(
      name: _string(json['name'], fallback.name),
      birthDate: _string(json['birthDate'], legacyBirthDate),
      heightCm: _double(json['heightCm'], fallback.heightCm),
      weightKg: _double(json['weightKg'], fallback.weightKg),
      country: _string(json['country'], fallback.country),
      city: _string(json['city'], fallback.city),
      climate: _string(json['climate'], fallback.climate),
      climateSummer: _string(json['climateSummer'], fallback.climateSummer),
      climateWinter: _string(json['climateWinter'], fallback.climateWinter),
      latitude: _nullableDouble(json['latitude']) ?? fallback.latitude,
      longitude: _nullableDouble(json['longitude']) ?? fallback.longitude,
      solarPhenomena: _stringList(
        json['solarPhenomena'],
        fallback.solarPhenomena,
      ),
      goal: _string(json['goal'], fallback.goal),
      trainingGoals: _stringList(json['trainingGoals'], fallback.trainingGoals),
      activityLevel: _string(json['activityLevel'], fallback.activityLevel),
      gender: _string(json['gender'], fallback.gender),
      favoriteFoods: _stringList(json['favoriteFoods'], fallback.favoriteFoods),
      dislikedFoods: _stringList(json['dislikedFoods'], fallback.dislikedFoods),
      dietType: _string(json['dietType'], fallback.dietType),
      foodBudget: _string(json['foodBudget'], fallback.foodBudget),
      maxCookingMinutes: _int(
        json['maxCookingMinutes'],
        fallback.maxCookingMinutes,
      ),
      recipeLanguage: _string(json['recipeLanguage'], fallback.recipeLanguage),
      workoutLanguage: _string(
        json['workoutLanguage'],
        fallback.workoutLanguage,
      ),
      timeZone: _string(json['timeZone'], fallback.timeZone),
      typicalTemperatureC: _double(
        json['typicalTemperatureC'],
        fallback.typicalTemperatureC,
      ),
      humidityPercent: _int(
        json['humidityPercent'],
        fallback.humidityPercent,
      ).clamp(0, 100),
      altitudeMeters: _int(
        json['altitudeMeters'],
        fallback.altitudeMeters,
      ).clamp(-500, 9000),
      airQuality: _string(json['airQuality'], fallback.airQuality),
      regionalAllergens: _stringList(
        json['regionalAllergens'],
        fallback.regionalAllergens,
      ),
      climateReactions: _stringList(
        json['climateReactions'],
        fallback.climateReactions,
      ),
      homeLatitude:
          _nullableDouble(json['homeLatitude']) ?? fallback.homeLatitude,
      homeLongitude:
          _nullableDouble(json['homeLongitude']) ?? fallback.homeLongitude,
      workLatitude:
          _nullableDouble(json['workLatitude']) ?? fallback.workLatitude,
      workLongitude:
          _nullableDouble(json['workLongitude']) ?? fallback.workLongitude,
      placeRadiusMeters: _int(
        json['placeRadiusMeters'],
        fallback.placeRadiusMeters,
      ).clamp(50, 2000),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'birthDate': birthDate,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'country': country,
    'city': city,
    'climate': climate,
    'climateSummer': climateSummer,
    'climateWinter': climateWinter,
    'latitude': latitude,
    'longitude': longitude,
    'solarPhenomena': solarPhenomena,
    'goal': goal,
    'trainingGoals': trainingGoals,
    'activityLevel': activityLevel,
    'gender': gender,
    'favoriteFoods': favoriteFoods,
    'dislikedFoods': dislikedFoods,
    'dietType': dietType,
    'foodBudget': foodBudget,
    'maxCookingMinutes': maxCookingMinutes,
    'recipeLanguage': recipeLanguage,
    'workoutLanguage': workoutLanguage,
    'timeZone': timeZone,
    'typicalTemperatureC': typicalTemperatureC,
    'humidityPercent': humidityPercent,
    'altitudeMeters': altitudeMeters,
    'airQuality': airQuality,
    'regionalAllergens': regionalAllergens,
    'climateReactions': climateReactions,
    'homeLatitude': homeLatitude,
    'homeLongitude': homeLongitude,
    'workLatitude': workLatitude,
    'workLongitude': workLongitude,
    'placeRadiusMeters': placeRadiusMeters,
  };

  UserProfile copyWith({
    String? name,
    String? birthDate,
    double? heightCm,
    double? weightKg,
    String? country,
    String? city,
    String? climate,
    String? climateSummer,
    String? climateWinter,
    double? latitude,
    double? longitude,
    List<String>? solarPhenomena,
    String? goal,
    List<String>? trainingGoals,
    String? activityLevel,
    String? gender,
    List<String>? favoriteFoods,
    List<String>? dislikedFoods,
    String? dietType,
    String? foodBudget,
    int? maxCookingMinutes,
    String? recipeLanguage,
    String? workoutLanguage,
    String? timeZone,
    double? typicalTemperatureC,
    int? humidityPercent,
    int? altitudeMeters,
    String? airQuality,
    List<String>? regionalAllergens,
    List<String>? climateReactions,
    double? homeLatitude,
    double? homeLongitude,
    double? workLatitude,
    double? workLongitude,
    int? placeRadiusMeters,
  }) {
    return UserProfile(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      country: country ?? this.country,
      city: city ?? this.city,
      climate: climate ?? this.climate,
      climateSummer: climateSummer ?? this.climateSummer,
      climateWinter: climateWinter ?? this.climateWinter,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      solarPhenomena: solarPhenomena ?? this.solarPhenomena,
      goal: goal ?? this.goal,
      trainingGoals: trainingGoals ?? this.trainingGoals,
      activityLevel: activityLevel ?? this.activityLevel,
      gender: gender ?? this.gender,
      favoriteFoods: favoriteFoods ?? this.favoriteFoods,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      dietType: dietType ?? this.dietType,
      foodBudget: foodBudget ?? this.foodBudget,
      maxCookingMinutes: maxCookingMinutes ?? this.maxCookingMinutes,
      recipeLanguage: recipeLanguage ?? this.recipeLanguage,
      workoutLanguage: workoutLanguage ?? this.workoutLanguage,
      timeZone: timeZone ?? this.timeZone,
      typicalTemperatureC: typicalTemperatureC ?? this.typicalTemperatureC,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      airQuality: airQuality ?? this.airQuality,
      regionalAllergens: regionalAllergens ?? this.regionalAllergens,
      climateReactions: climateReactions ?? this.climateReactions,
      homeLatitude: homeLatitude ?? this.homeLatitude,
      homeLongitude: homeLongitude ?? this.homeLongitude,
      workLatitude: workLatitude ?? this.workLatitude,
      workLongitude: workLongitude ?? this.workLongitude,
      placeRadiusMeters: (placeRadiusMeters ?? this.placeRadiusMeters).clamp(
        50,
        2000,
      ),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.advancedMode = true,
    this.largeText = false,
    this.highContrast = false,
    this.aiEnabled = true,
    this.requireRecognitionConfirmation = true,
    this.showMedicalDisclaimer = true,
    this.encryptedVault = true,
    this.pinEnabled = false,
    this.biometricEnabled = false,
    this.medicalLock = true,
    this.hideLockScreenNotifications = true,
    this.offlineOnly = true,
    this.motivationStrictness = 2,
    this.uiScale = 1.0,
    this.geolocationEnabled = true,
    this.openStreetMapEnabled = true,
    this.offlineMapDownloadEnabled = true,
    this.unitSystem = 'metric',
    this.dateDisplayFormat = 'dd.mm.yyyy',
    this.timeFormat = '24h',
    this.distanceUnit = 'km',
    this.temperatureUnit = 'celsius',
    this.bodyWeightUnit = 'kg',
    this.heightUnit = 'cm',
    this.notificationsEnabled = true,
    this.medicationNotifications = true,
    this.activityNotifications = true,
    this.alarmNotifications = true,
    this.pinHash = '',
    this.pinSalt = '',
  });

  final String themeMode;
  final bool advancedMode;
  final bool largeText;
  final bool highContrast;
  final bool aiEnabled;
  final bool requireRecognitionConfirmation;
  final bool showMedicalDisclaimer;
  final bool encryptedVault;
  final bool pinEnabled;
  final bool biometricEnabled;
  final bool medicalLock;
  final bool hideLockScreenNotifications;
  final bool offlineOnly;
  final int motivationStrictness;
  final double uiScale;
  final bool geolocationEnabled;
  final bool openStreetMapEnabled;
  final bool offlineMapDownloadEnabled;
  final String unitSystem;
  final String dateDisplayFormat;
  final String timeFormat;
  final String distanceUnit;
  final String temperatureUnit;
  final String bodyWeightUnit;
  final String heightUnit;
  final bool notificationsEnabled;
  final bool medicationNotifications;
  final bool activityNotifications;
  final bool alarmNotifications;
  final String pinHash;
  final String pinSalt;

  factory AppSettings.fromJson(
    Map<String, dynamic> json,
    AppSettings fallback,
  ) {
    return AppSettings(
      themeMode: _string(json['themeMode'], fallback.themeMode),
      advancedMode: _bool(json['advancedMode'], fallback.advancedMode),
      largeText: _bool(json['largeText'], fallback.largeText),
      highContrast: _bool(json['highContrast'], fallback.highContrast),
      aiEnabled: _bool(json['aiEnabled'], fallback.aiEnabled),
      requireRecognitionConfirmation: _bool(
        json['requireRecognitionConfirmation'],
        fallback.requireRecognitionConfirmation,
      ),
      showMedicalDisclaimer: _bool(
        json['showMedicalDisclaimer'],
        fallback.showMedicalDisclaimer,
      ),
      encryptedVault: _bool(json['encryptedVault'], fallback.encryptedVault),
      pinEnabled: _bool(json['pinEnabled'], fallback.pinEnabled),
      biometricEnabled: _bool(
        json['biometricEnabled'],
        fallback.biometricEnabled,
      ),
      medicalLock: _bool(json['medicalLock'], fallback.medicalLock),
      hideLockScreenNotifications: _bool(
        json['hideLockScreenNotifications'],
        fallback.hideLockScreenNotifications,
      ),
      offlineOnly: _bool(json['offlineOnly'], fallback.offlineOnly),
      motivationStrictness: _int(
        json['motivationStrictness'],
        fallback.motivationStrictness,
      ),
      uiScale: _double(
        json['uiScale'],
        fallback.uiScale,
      ).clamp(0.8, 1.6).toDouble(),
      geolocationEnabled: _bool(
        json['geolocationEnabled'],
        fallback.geolocationEnabled,
      ),
      openStreetMapEnabled: _bool(
        json['openStreetMapEnabled'],
        fallback.openStreetMapEnabled,
      ),
      offlineMapDownloadEnabled: _bool(
        json['offlineMapDownloadEnabled'],
        fallback.offlineMapDownloadEnabled,
      ),
      unitSystem: _string(json['unitSystem'], fallback.unitSystem),
      dateDisplayFormat: _string(
        json['dateDisplayFormat'],
        fallback.dateDisplayFormat,
      ),
      timeFormat: _string(json['timeFormat'], fallback.timeFormat),
      distanceUnit: _string(json['distanceUnit'], fallback.distanceUnit),
      temperatureUnit: _string(
        json['temperatureUnit'],
        fallback.temperatureUnit,
      ),
      bodyWeightUnit: _string(json['bodyWeightUnit'], fallback.bodyWeightUnit),
      heightUnit: _string(json['heightUnit'], fallback.heightUnit),
      notificationsEnabled: _bool(
        json['notificationsEnabled'],
        fallback.notificationsEnabled,
      ),
      medicationNotifications: _bool(
        json['medicationNotifications'],
        fallback.medicationNotifications,
      ),
      activityNotifications: _bool(
        json['activityNotifications'],
        fallback.activityNotifications,
      ),
      alarmNotifications: _bool(
        json['alarmNotifications'],
        fallback.alarmNotifications,
      ),
      pinHash: _string(json['pinHash'], fallback.pinHash),
      pinSalt: _string(json['pinSalt'], fallback.pinSalt),
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode,
    'advancedMode': advancedMode,
    'largeText': largeText,
    'highContrast': highContrast,
    'aiEnabled': aiEnabled,
    'requireRecognitionConfirmation': requireRecognitionConfirmation,
    'showMedicalDisclaimer': showMedicalDisclaimer,
    'encryptedVault': encryptedVault,
    'pinEnabled': pinEnabled,
    'biometricEnabled': biometricEnabled,
    'medicalLock': medicalLock,
    'hideLockScreenNotifications': hideLockScreenNotifications,
    'offlineOnly': offlineOnly,
    'motivationStrictness': motivationStrictness,
    'uiScale': uiScale,
    'geolocationEnabled': geolocationEnabled,
    'openStreetMapEnabled': openStreetMapEnabled,
    'offlineMapDownloadEnabled': offlineMapDownloadEnabled,
    'unitSystem': unitSystem,
    'dateDisplayFormat': dateDisplayFormat,
    'timeFormat': timeFormat,
    'distanceUnit': distanceUnit,
    'temperatureUnit': temperatureUnit,
    'bodyWeightUnit': bodyWeightUnit,
    'heightUnit': heightUnit,
    'notificationsEnabled': notificationsEnabled,
    'medicationNotifications': medicationNotifications,
    'activityNotifications': activityNotifications,
    'alarmNotifications': alarmNotifications,
    'pinHash': pinHash,
    'pinSalt': pinSalt,
  };

  AppSettings copyWith({
    String? themeMode,
    bool? advancedMode,
    bool? largeText,
    bool? highContrast,
    bool? aiEnabled,
    bool? requireRecognitionConfirmation,
    bool? showMedicalDisclaimer,
    bool? encryptedVault,
    bool? pinEnabled,
    bool? biometricEnabled,
    bool? medicalLock,
    bool? hideLockScreenNotifications,
    bool? offlineOnly,
    int? motivationStrictness,
    double? uiScale,
    bool? geolocationEnabled,
    bool? openStreetMapEnabled,
    bool? offlineMapDownloadEnabled,
    String? unitSystem,
    String? dateDisplayFormat,
    String? timeFormat,
    String? distanceUnit,
    String? temperatureUnit,
    String? bodyWeightUnit,
    String? heightUnit,
    bool? notificationsEnabled,
    bool? medicationNotifications,
    bool? activityNotifications,
    bool? alarmNotifications,
    String? pinHash,
    String? pinSalt,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      advancedMode: advancedMode ?? this.advancedMode,
      largeText: largeText ?? this.largeText,
      highContrast: highContrast ?? this.highContrast,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      requireRecognitionConfirmation:
          requireRecognitionConfirmation ?? this.requireRecognitionConfirmation,
      showMedicalDisclaimer:
          showMedicalDisclaimer ?? this.showMedicalDisclaimer,
      encryptedVault: encryptedVault ?? this.encryptedVault,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      medicalLock: medicalLock ?? this.medicalLock,
      hideLockScreenNotifications:
          hideLockScreenNotifications ?? this.hideLockScreenNotifications,
      offlineOnly: offlineOnly ?? this.offlineOnly,
      motivationStrictness: motivationStrictness ?? this.motivationStrictness,
      uiScale: (uiScale ?? this.uiScale).clamp(0.8, 1.6).toDouble(),
      geolocationEnabled: geolocationEnabled ?? this.geolocationEnabled,
      openStreetMapEnabled: openStreetMapEnabled ?? this.openStreetMapEnabled,
      offlineMapDownloadEnabled:
          offlineMapDownloadEnabled ?? this.offlineMapDownloadEnabled,
      unitSystem: unitSystem ?? this.unitSystem,
      dateDisplayFormat: dateDisplayFormat ?? this.dateDisplayFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      bodyWeightUnit: bodyWeightUnit ?? this.bodyWeightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      medicationNotifications:
          medicationNotifications ?? this.medicationNotifications,
      activityNotifications:
          activityNotifications ?? this.activityNotifications,
      alarmNotifications: alarmNotifications ?? this.alarmNotifications,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
    );
  }
}

class DailyMetrics {
  const DailyMetrics({
    required this.date,
    required this.weightKg,
    required this.sleepHours,
    required this.steps,
    required this.waterLiters,
    required this.calories,
    this.activeCalories = 0,
    required this.workoutMinutes,
    required this.mood,
    required this.stress,
    required this.medicationTaken,
    required this.symptoms,
  });

  final String date;
  final double weightKg;
  final double sleepHours;
  final int steps;
  final double waterLiters;
  final int calories;
  final int activeCalories;
  final int workoutMinutes;
  final int mood;
  final int stress;
  final bool medicationTaken;
  final List<String> symptoms;

  factory DailyMetrics.empty(String date) => DailyMetrics(
    date: date,
    weightKg: 0,
    sleepHours: 0,
    steps: 0,
    waterLiters: 0,
    calories: 0,
    activeCalories: 0,
    workoutMinutes: 0,
    mood: 0,
    stress: 0,
    medicationTaken: false,
    symptoms: const [],
  );

  factory DailyMetrics.fromJsonSafe(Map<String, dynamic> json) {
    return DailyMetrics.fromJson(
      json,
      DailyMetrics.empty(_string(json['date'], todayKey())),
    );
  }

  factory DailyMetrics.fromJson(
    Map<String, dynamic> json,
    DailyMetrics fallback,
  ) {
    return DailyMetrics(
      date: _string(json['date'], fallback.date),
      weightKg: _double(json['weightKg'], fallback.weightKg),
      sleepHours: _double(json['sleepHours'], fallback.sleepHours),
      steps: _int(json['steps'], fallback.steps),
      waterLiters: _double(json['waterLiters'], fallback.waterLiters),
      calories: _int(json['calories'], fallback.calories),
      activeCalories: _int(json['activeCalories'], fallback.activeCalories),
      workoutMinutes: _int(json['workoutMinutes'], fallback.workoutMinutes),
      mood: _int(json['mood'], fallback.mood),
      stress: _int(json['stress'], fallback.stress),
      medicationTaken: _bool(json['medicationTaken'], fallback.medicationTaken),
      symptoms: _stringList(json['symptoms'], fallback.symptoms),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'weightKg': weightKg,
    'sleepHours': sleepHours,
    'steps': steps,
    'waterLiters': waterLiters,
    'calories': calories,
    'activeCalories': activeCalories,
    'workoutMinutes': workoutMinutes,
    'mood': mood,
    'stress': stress,
    'medicationTaken': medicationTaken,
    'symptoms': symptoms,
  };

  DailyMetrics copyWith({
    String? date,
    double? weightKg,
    double? sleepHours,
    int? steps,
    double? waterLiters,
    int? calories,
    int? activeCalories,
    int? workoutMinutes,
    int? mood,
    int? stress,
    bool? medicationTaken,
    List<String>? symptoms,
  }) {
    return DailyMetrics(
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      sleepHours: sleepHours ?? this.sleepHours,
      steps: steps ?? this.steps,
      waterLiters: waterLiters ?? this.waterLiters,
      calories: calories ?? this.calories,
      activeCalories: activeCalories ?? this.activeCalories,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      mood: mood ?? this.mood,
      stress: stress ?? this.stress,
      medicationTaken: medicationTaken ?? this.medicationTaken,
      symptoms: symptoms ?? this.symptoms,
    );
  }
}

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.schedule,
    required this.takenToday,
    required this.notes,
    this.category = 'лекарство',
    this.loggedDate = '',
    this.form = '',
    this.courseStart = '',
    this.courseEnd = '',
    this.foodRule = '',
    this.prescribingDoctor = '',
    this.linkedCondition = '',
    this.remainingUnits = 0,
    this.lowStockThreshold = 0,
    this.sideEffects = '',
    this.purchaseReminder = false,
  });

  final String id;
  final String name;
  final String dose;
  final String schedule;
  final bool takenToday;
  final String notes;
  final String category;
  final String loggedDate;
  final String form;
  final String courseStart;
  final String courseEnd;
  final String foodRule;
  final String prescribingDoctor;
  final String linkedCondition;
  final int remainingUnits;
  final int lowStockThreshold;
  final String sideEffects;
  final bool purchaseReminder;

  bool get stockIsLow =>
      purchaseReminder &&
      lowStockThreshold > 0 &&
      remainingUnits > 0 &&
      remainingUnits <= lowStockThreshold;

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: _string(json['id'], newId()),
    name: _string(json['name'], ''),
    dose: _string(json['dose'], ''),
    schedule: _string(json['schedule'], ''),
    takenToday: _bool(json['takenToday'], false),
    notes: _string(json['notes'], ''),
    category: _string(json['category'], 'лекарство'),
    loggedDate: _string(json['loggedDate'], todayKey()),
    form: _string(json['form'], ''),
    courseStart: _string(json['courseStart'], ''),
    courseEnd: _string(json['courseEnd'], ''),
    foodRule: _string(json['foodRule'], ''),
    prescribingDoctor: _string(json['prescribingDoctor'], ''),
    linkedCondition: _string(json['linkedCondition'], ''),
    remainingUnits: _int(json['remainingUnits'], 0),
    lowStockThreshold: _int(json['lowStockThreshold'], 0),
    sideEffects: _string(json['sideEffects'], ''),
    purchaseReminder: _bool(json['purchaseReminder'], false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dose': dose,
    'schedule': schedule,
    'takenToday': takenToday,
    'notes': notes,
    'category': category,
    'loggedDate': loggedDate,
    'form': form,
    'courseStart': courseStart,
    'courseEnd': courseEnd,
    'foodRule': foodRule,
    'prescribingDoctor': prescribingDoctor,
    'linkedCondition': linkedCondition,
    'remainingUnits': remainingUnits,
    'lowStockThreshold': lowStockThreshold,
    'sideEffects': sideEffects,
    'purchaseReminder': purchaseReminder,
  };

  Medication copyWith({
    String? name,
    String? dose,
    String? schedule,
    bool? takenToday,
    String? notes,
    String? category,
    String? loggedDate,
    String? form,
    String? courseStart,
    String? courseEnd,
    String? foodRule,
    String? prescribingDoctor,
    String? linkedCondition,
    int? remainingUnits,
    int? lowStockThreshold,
    String? sideEffects,
    bool? purchaseReminder,
  }) => Medication(
    id: id,
    name: name ?? this.name,
    dose: dose ?? this.dose,
    schedule: schedule ?? this.schedule,
    takenToday: takenToday ?? this.takenToday,
    notes: notes ?? this.notes,
    category: category ?? this.category,
    loggedDate: loggedDate ?? this.loggedDate,
    form: form ?? this.form,
    courseStart: courseStart ?? this.courseStart,
    courseEnd: courseEnd ?? this.courseEnd,
    foodRule: foodRule ?? this.foodRule,
    prescribingDoctor: prescribingDoctor ?? this.prescribingDoctor,
    linkedCondition: linkedCondition ?? this.linkedCondition,
    remainingUnits: remainingUnits ?? this.remainingUnits,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    sideEffects: sideEffects ?? this.sideEffects,
    purchaseReminder: purchaseReminder ?? this.purchaseReminder,
  );
}

class MedicationIntake {
  const MedicationIntake({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.dose,
    required this.date,
    required this.time,
    required this.status,
    required this.notes,
  });

  final String id;
  final String medicationId;
  final String medicationName;
  final String dose;
  final String date;
  final String time;
  final String status;
  final String notes;

  factory MedicationIntake.fromJson(Map<String, dynamic> json) =>
      MedicationIntake(
        id: _string(json['id'], newId()),
        medicationId: _string(json['medicationId'], ''),
        medicationName: _string(json['medicationName'], ''),
        dose: _string(json['dose'], ''),
        date: _string(json['date'], todayKey()),
        time: _string(json['time'], ''),
        status: _string(json['status'], 'принято'),
        notes: _string(json['notes'], ''),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'medicationId': medicationId,
    'medicationName': medicationName,
    'dose': dose,
    'date': date,
    'time': time,
    'status': status,
    'notes': notes,
  };

  MedicationIntake copyWith({
    String? medicationId,
    String? medicationName,
    String? dose,
    String? date,
    String? time,
    String? status,
    String? notes,
  }) => MedicationIntake(
    id: id,
    medicationId: medicationId ?? this.medicationId,
    medicationName: medicationName ?? this.medicationName,
    dose: dose ?? this.dose,
    date: date ?? this.date,
    time: time ?? this.time,
    status: status ?? this.status,
    notes: notes ?? this.notes,
  );
}

class LabResult {
  const LabResult({
    required this.id,
    required this.marker,
    required this.value,
    required this.unit,
    required this.reference,
    required this.date,
    required this.needsAttention,
    required this.notes,
  });

  final String id;
  final String marker;
  final String value;
  final String unit;
  final String reference;
  final String date;
  final bool needsAttention;
  final String notes;

  String get referenceStatus {
    final numeric = double.tryParse(value.replaceAll(',', '.'));
    if (numeric == null) {
      return needsAttention ? 'требует проверки' : 'не определено';
    }
    final numbers = RegExp(r'-?\d+(?:[\.,]\d+)?')
        .allMatches(reference)
        .map((match) => double.tryParse(match.group(0)!.replaceAll(',', '.')))
        .whereType<double>()
        .toList();
    if (numbers.length >= 2) {
      final low = numbers[0] < numbers[1] ? numbers[0] : numbers[1];
      final high = numbers[0] < numbers[1] ? numbers[1] : numbers[0];
      if (numeric < low) return 'ниже референса';
      if (numeric > high) return 'выше референса';
      return 'в пределах референса';
    }
    if (numbers.length == 1) {
      final boundary = numbers.first;
      final lower = reference.toLowerCase();
      if (lower.contains('<') ||
          lower.contains('до') ||
          lower.contains('less')) {
        return numeric <= boundary ? 'в пределах референса' : 'выше референса';
      }
      if (lower.contains('>') ||
          lower.contains('от') ||
          lower.contains('more')) {
        return numeric >= boundary ? 'в пределах референса' : 'ниже референса';
      }
    }
    return needsAttention ? 'требует проверки' : 'не определено';
  }

  bool get outsideReference =>
      referenceStatus == 'ниже референса' ||
      referenceStatus == 'выше референса' ||
      needsAttention;

  factory LabResult.fromJson(Map<String, dynamic> json) => LabResult(
    id: _string(json['id'], newId()),
    marker: _string(json['marker'], ''),
    value: _string(json['value'], ''),
    unit: _string(json['unit'], ''),
    reference: _string(json['reference'], ''),
    date: _string(json['date'], todayKey()),
    needsAttention: _bool(json['needsAttention'], false),
    notes: _string(json['notes'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'marker': marker,
    'value': value,
    'unit': unit,
    'reference': reference,
    'date': date,
    'needsAttention': needsAttention,
    'notes': notes,
  };

  LabResult copyWith({
    String? marker,
    String? value,
    String? unit,
    String? reference,
    String? date,
    bool? needsAttention,
    String? notes,
  }) => LabResult(
    id: id,
    marker: marker ?? this.marker,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    reference: reference ?? this.reference,
    date: date ?? this.date,
    needsAttention: needsAttention ?? this.needsAttention,
    notes: notes ?? this.notes,
  );
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.title,
    required this.kind,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confirmed,
    required this.notes,
    this.date = '',
    this.imagePath = '',
    this.source = 'manual',
    this.time = '',
    this.portionGrams = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.salt = 0,
  });

  final String id;
  final String title;
  final String kind;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final bool confirmed;
  final String notes;
  final String date;
  final String imagePath;
  final String source;
  final String time;
  final int portionGrams;
  final int fiber;
  final int sugar;
  final double salt;

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    kind: _string(json['kind'], ''),
    calories: _int(json['calories'], 0),
    protein: _int(json['protein'], 0),
    carbs: _int(json['carbs'], 0),
    fat: _int(json['fat'], 0),
    confirmed: _bool(json['confirmed'], false),
    notes: _string(json['notes'], ''),
    date: _string(json['date'], todayKey()),
    imagePath: _string(json['imagePath'], ''),
    source: _string(json['source'], 'manual'),
    time: _string(json['time'], ''),
    portionGrams: _int(json['portionGrams'], 0),
    fiber: _int(json['fiber'], 0),
    sugar: _int(json['sugar'], 0),
    salt: _double(json['salt'], 0),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'confirmed': confirmed,
    'notes': notes,
    'date': date,
    'imagePath': imagePath,
    'source': source,
    'time': time,
    'portionGrams': portionGrams,
    'fiber': fiber,
    'sugar': sugar,
    'salt': salt,
  };

  MealEntry copyWith({
    String? title,
    String? kind,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    bool? confirmed,
    String? notes,
    String? date,
    String? imagePath,
    String? source,
    String? time,
    int? portionGrams,
    int? fiber,
    int? sugar,
    double? salt,
  }) => MealEntry(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    confirmed: confirmed ?? this.confirmed,
    notes: notes ?? this.notes,
    date: date ?? this.date,
    imagePath: imagePath ?? this.imagePath,
    source: source ?? this.source,
    time: time ?? this.time,
    portionGrams: portionGrams ?? this.portionGrams,
    fiber: fiber ?? this.fiber,
    sugar: sugar ?? this.sugar,
    salt: salt ?? this.salt,
  );
}

class SymptomEntry {
  const SymptomEntry({
    required this.id,
    required this.symptom,
    required this.date,
    required this.time,
    required this.intensity,
    this.notes = '',
    this.temperatureC,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.linkedMealIds = const [],
    this.linkedMedicationIds = const [],
    this.linkedWorkoutIds = const [],
    this.linkedSleepRecordId = '',
    this.linkedTripId = '',
    this.linkedVacationId = '',
    this.climateSnapshot = '',
    this.needsAttention = false,
  });

  final String id;
  final String symptom;
  final String date;
  final String time;
  final int intensity;
  final String notes;
  final double? temperatureC;
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final List<String> linkedMealIds;
  final List<String> linkedMedicationIds;
  final List<String> linkedWorkoutIds;
  final String linkedSleepRecordId;
  final String linkedTripId;
  final String linkedVacationId;
  final String climateSnapshot;
  final bool needsAttention;

  factory SymptomEntry.fromJson(Map<String, dynamic> json) => SymptomEntry(
    id: _string(json['id'], newId()),
    symptom: _string(json['symptom'], ''),
    date: _string(json['date'], todayKey()),
    time: _string(json['time'], ''),
    intensity: _int(json['intensity'], 1).clamp(1, 10),
    notes: _string(json['notes'], ''),
    temperatureC: _nullableDouble(json['temperatureC']),
    systolic: _nullableInt(json['systolic']),
    diastolic: _nullableInt(json['diastolic']),
    pulse: _nullableInt(json['pulse']),
    linkedMealIds: _stringList(json['linkedMealIds'], const []),
    linkedMedicationIds: _stringList(json['linkedMedicationIds'], const []),
    linkedWorkoutIds: _stringList(json['linkedWorkoutIds'], const []),
    linkedSleepRecordId: _string(json['linkedSleepRecordId'], ''),
    linkedTripId: _string(json['linkedTripId'], ''),
    linkedVacationId: _string(json['linkedVacationId'], ''),
    climateSnapshot: _string(json['climateSnapshot'], ''),
    needsAttention: _bool(json['needsAttention'], false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'symptom': symptom,
    'date': date,
    'time': time,
    'intensity': intensity,
    'notes': notes,
    'temperatureC': temperatureC,
    'systolic': systolic,
    'diastolic': diastolic,
    'pulse': pulse,
    'linkedMealIds': linkedMealIds,
    'linkedMedicationIds': linkedMedicationIds,
    'linkedWorkoutIds': linkedWorkoutIds,
    'linkedSleepRecordId': linkedSleepRecordId,
    'linkedTripId': linkedTripId,
    'linkedVacationId': linkedVacationId,
    'climateSnapshot': climateSnapshot,
    'needsAttention': needsAttention,
  };

  SymptomEntry copyWith({
    String? symptom,
    String? date,
    String? time,
    int? intensity,
    String? notes,
    double? temperatureC,
    int? systolic,
    int? diastolic,
    int? pulse,
    List<String>? linkedMealIds,
    List<String>? linkedMedicationIds,
    List<String>? linkedWorkoutIds,
    String? linkedSleepRecordId,
    String? linkedTripId,
    String? linkedVacationId,
    String? climateSnapshot,
    bool? needsAttention,
  }) => SymptomEntry(
    id: id,
    symptom: symptom ?? this.symptom,
    date: date ?? this.date,
    time: time ?? this.time,
    intensity: intensity ?? this.intensity,
    notes: notes ?? this.notes,
    temperatureC: temperatureC ?? this.temperatureC,
    systolic: systolic ?? this.systolic,
    diastolic: diastolic ?? this.diastolic,
    pulse: pulse ?? this.pulse,
    linkedMealIds: linkedMealIds ?? this.linkedMealIds,
    linkedMedicationIds: linkedMedicationIds ?? this.linkedMedicationIds,
    linkedWorkoutIds: linkedWorkoutIds ?? this.linkedWorkoutIds,
    linkedSleepRecordId: linkedSleepRecordId ?? this.linkedSleepRecordId,
    linkedTripId: linkedTripId ?? this.linkedTripId,
    linkedVacationId: linkedVacationId ?? this.linkedVacationId,
    climateSnapshot: climateSnapshot ?? this.climateSnapshot,
    needsAttention: needsAttention ?? this.needsAttention,
  );
}

class SleepRecord {
  const SleepRecord({
    required this.id,
    required this.date,
    required this.bedTime,
    required this.wakeTime,
    required this.durationMinutes,
    required this.quality,
    this.awakenings = 0,
    this.source = 'manual',
    this.timeZone = '',
    this.notes = '',
  });

  final String id;
  final String date;
  final String bedTime;
  final String wakeTime;
  final int durationMinutes;
  final int quality;
  final int awakenings;
  final String source;
  final String timeZone;
  final String notes;

  double get durationHours => durationMinutes / 60;

  factory SleepRecord.fromJson(Map<String, dynamic> json) => SleepRecord(
    id: _string(json['id'], newId()),
    date: _string(json['date'], todayKey()),
    bedTime: _string(json['bedTime'], ''),
    wakeTime: _string(json['wakeTime'], ''),
    durationMinutes: _int(json['durationMinutes'], 0),
    quality: _int(json['quality'], 3).clamp(1, 5),
    awakenings: _int(json['awakenings'], 0),
    source: _string(json['source'], 'manual'),
    timeZone: _string(json['timeZone'], ''),
    notes: _string(json['notes'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'bedTime': bedTime,
    'wakeTime': wakeTime,
    'durationMinutes': durationMinutes,
    'quality': quality,
    'awakenings': awakenings,
    'source': source,
    'timeZone': timeZone,
    'notes': notes,
  };

  SleepRecord copyWith({
    String? date,
    String? bedTime,
    String? wakeTime,
    int? durationMinutes,
    int? quality,
    int? awakenings,
    String? source,
    String? timeZone,
    String? notes,
  }) => SleepRecord(
    id: id,
    date: date ?? this.date,
    bedTime: bedTime ?? this.bedTime,
    wakeTime: wakeTime ?? this.wakeTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    quality: quality ?? this.quality,
    awakenings: awakenings ?? this.awakenings,
    source: source ?? this.source,
    timeZone: timeZone ?? this.timeZone,
    notes: notes ?? this.notes,
  );
}

class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters = 0,
    this.speedKmh = 0,
  });

  final double latitude;
  final double longitude;
  final String timestamp;
  final double accuracyMeters;
  final double speedKmh;

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    latitude: _double(json['latitude'], 0),
    longitude: _double(json['longitude'], 0),
    timestamp: _string(json['timestamp'], ''),
    accuracyMeters: _double(json['accuracyMeters'], 0),
    speedKmh: _double(json['speedKmh'], 0),
  );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp,
    'accuracyMeters': accuracyMeters,
    'speedKmh': speedKmh,
  };
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.title,
    required this.focus,
    required this.minutes,
    required this.intensity,
    required this.scheduledDate,
    required this.exerciseIds,
    this.notes = '',
    this.mode = 'manual',
    this.distanceMeters = 0,
    this.elapsedSeconds = 0,
    this.averageSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.caloriesBurned = 0,
    this.geoPath = const [],
    this.status = 'planned',
    this.completedAt = '',
    this.perceivedEffort = 0,
    this.feedback = '',
    this.exerciseResults = const [],
  });

  final String id;
  final String title;
  final String focus;
  final int minutes;
  final String intensity;
  final String scheduledDate;
  final List<String> exerciseIds;
  final String notes;
  final String mode;
  final double distanceMeters;
  final int elapsedSeconds;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final int caloriesBurned;
  final List<GeoPoint> geoPath;
  final String status;
  final String completedAt;
  final int perceivedEffort;
  final String feedback;
  final List<WorkoutExerciseResult> exerciseResults;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    focus: _string(json['focus'], ''),
    minutes: _int(json['minutes'], 0),
    intensity: _string(json['intensity'], ''),
    scheduledDate: _string(json['scheduledDate'], todayKey()),
    exerciseIds: _stringList(json['exerciseIds'], const []),
    notes: _string(json['notes'], ''),
    mode: _string(json['mode'], 'manual'),
    distanceMeters: _double(json['distanceMeters'], 0),
    elapsedSeconds: _int(json['elapsedSeconds'], 0),
    averageSpeedKmh: _double(json['averageSpeedKmh'], 0),
    maxSpeedKmh: _double(json['maxSpeedKmh'], 0),
    caloriesBurned: _int(json['caloriesBurned'], 0),
    geoPath: _objectList(json['geoPath'], GeoPoint.fromJson),
    status: _string(json['status'], 'planned'),
    completedAt: _string(json['completedAt'], ''),
    perceivedEffort: _int(json['perceivedEffort'], 0),
    feedback: _string(json['feedback'], ''),
    exerciseResults: _objectList(
      json['exerciseResults'],
      WorkoutExerciseResult.fromJson,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'focus': focus,
    'minutes': minutes,
    'intensity': intensity,
    'scheduledDate': scheduledDate,
    'exerciseIds': exerciseIds,
    'notes': notes,
    'mode': mode,
    'distanceMeters': distanceMeters,
    'elapsedSeconds': elapsedSeconds,
    'averageSpeedKmh': averageSpeedKmh,
    'maxSpeedKmh': maxSpeedKmh,
    'caloriesBurned': caloriesBurned,
    'geoPath': geoPath.map((item) => item.toJson()).toList(),
    'status': status,
    'completedAt': completedAt,
    'perceivedEffort': perceivedEffort,
    'feedback': feedback,
    'exerciseResults': exerciseResults.map((item) => item.toJson()).toList(),
  };

  WorkoutSession copyWith({
    String? title,
    String? focus,
    int? minutes,
    String? intensity,
    String? scheduledDate,
    List<String>? exerciseIds,
    String? notes,
    String? mode,
    double? distanceMeters,
    int? elapsedSeconds,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    int? caloriesBurned,
    List<GeoPoint>? geoPath,
    String? status,
    String? completedAt,
    int? perceivedEffort,
    String? feedback,
    List<WorkoutExerciseResult>? exerciseResults,
  }) => WorkoutSession(
    id: id,
    title: title ?? this.title,
    focus: focus ?? this.focus,
    minutes: minutes ?? this.minutes,
    intensity: intensity ?? this.intensity,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    exerciseIds: exerciseIds ?? this.exerciseIds,
    notes: notes ?? this.notes,
    mode: mode ?? this.mode,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
    maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
    caloriesBurned: caloriesBurned ?? this.caloriesBurned,
    geoPath: geoPath ?? this.geoPath,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    perceivedEffort: perceivedEffort ?? this.perceivedEffort,
    feedback: feedback ?? this.feedback,
    exerciseResults: exerciseResults ?? this.exerciseResults,
  );
}

class WorkoutExerciseResult {
  const WorkoutExerciseResult({
    required this.exerciseId,
    required this.title,
    required this.setsCompleted,
    required this.repetitions,
    required this.seconds,
    this.difficulty = 'нормально',
    this.pain = false,
    this.notes = '',
  });

  final String exerciseId;
  final String title;
  final int setsCompleted;
  final int repetitions;
  final int seconds;
  final String difficulty;
  final bool pain;
  final String notes;

  factory WorkoutExerciseResult.fromJson(Map<String, dynamic> json) =>
      WorkoutExerciseResult(
        exerciseId: _string(json['exerciseId'], ''),
        title: _string(json['title'], ''),
        setsCompleted: _int(json['setsCompleted'], 0),
        repetitions: _int(json['repetitions'], 0),
        seconds: _int(json['seconds'], 0),
        difficulty: _string(json['difficulty'], 'нормально'),
        pain: _bool(json['pain'], false),
        notes: _string(json['notes'], ''),
      );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'title': title,
    'setsCompleted': setsCompleted,
    'repetitions': repetitions,
    'seconds': seconds,
    'difficulty': difficulty,
    'pain': pain,
    'notes': notes,
  };
}

class AlarmGroup {
  const AlarmGroup({
    required this.id,
    required this.title,
    required this.wakeTime,
    required this.bedTime,
    required this.days,
    required this.adaptive,
    this.context = 'обычный',
    this.priority = 2,
    this.unlockMode = 'simple',
    this.specificDate = '',
    this.dutyAware = false,
    this.vacationAware = false,
    this.smartWakeWindowMinutes = 0,
    this.useWearableSleepCycle = false,
    this.vibrationEnabled = true,
    this.gradualWakeEnabled = true,
    this.gradualWakeMinutes = 3,
  });

  final String id;
  final String title;
  final String wakeTime;
  final String bedTime;
  final String days;
  final bool adaptive;
  final String context;
  final int priority;
  final String unlockMode;
  final String specificDate;
  final bool dutyAware;
  final bool vacationAware;
  final int smartWakeWindowMinutes;
  final bool useWearableSleepCycle;
  final bool vibrationEnabled;
  final bool gradualWakeEnabled;
  final int gradualWakeMinutes;

  factory AlarmGroup.fromJson(Map<String, dynamic> json) => AlarmGroup(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    wakeTime: _string(json['wakeTime'], ''),
    bedTime: _string(json['bedTime'], ''),
    days: _string(json['days'], ''),
    adaptive: _bool(json['adaptive'], false),
    context: _string(json['context'], 'обычный'),
    priority: _int(json['priority'], 2),
    unlockMode: _string(json['unlockMode'], 'simple'),
    specificDate: _string(json['specificDate'], ''),
    dutyAware: _bool(json['dutyAware'], false),
    vacationAware: _bool(json['vacationAware'], false),
    smartWakeWindowMinutes: _int(json['smartWakeWindowMinutes'], 0),
    useWearableSleepCycle: _bool(json['useWearableSleepCycle'], false),
    vibrationEnabled: _bool(json['vibrationEnabled'], true),
    gradualWakeEnabled: _bool(json['gradualWakeEnabled'], true),
    gradualWakeMinutes: _int(json['gradualWakeMinutes'], 3),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'wakeTime': wakeTime,
    'bedTime': bedTime,
    'days': days,
    'adaptive': adaptive,
    'context': context,
    'priority': priority,
    'unlockMode': unlockMode,
    'specificDate': specificDate,
    'dutyAware': dutyAware,
    'vacationAware': vacationAware,
    'smartWakeWindowMinutes': smartWakeWindowMinutes,
    'useWearableSleepCycle': useWearableSleepCycle,
    'vibrationEnabled': vibrationEnabled,
    'gradualWakeEnabled': gradualWakeEnabled,
    'gradualWakeMinutes': gradualWakeMinutes,
  };

  AlarmGroup copyWith({
    String? title,
    String? wakeTime,
    String? bedTime,
    String? days,
    bool? adaptive,
    String? context,
    int? priority,
    String? unlockMode,
    String? specificDate,
    bool? dutyAware,
    bool? vacationAware,
    int? smartWakeWindowMinutes,
    bool? useWearableSleepCycle,
    bool? vibrationEnabled,
    bool? gradualWakeEnabled,
    int? gradualWakeMinutes,
  }) => AlarmGroup(
    id: id,
    title: title ?? this.title,
    wakeTime: wakeTime ?? this.wakeTime,
    bedTime: bedTime ?? this.bedTime,
    days: days ?? this.days,
    adaptive: adaptive ?? this.adaptive,
    context: context ?? this.context,
    priority: priority ?? this.priority,
    unlockMode: unlockMode ?? this.unlockMode,
    specificDate: specificDate ?? this.specificDate,
    dutyAware: dutyAware ?? this.dutyAware,
    vacationAware: vacationAware ?? this.vacationAware,
    smartWakeWindowMinutes:
        smartWakeWindowMinutes ?? this.smartWakeWindowMinutes,
    useWearableSleepCycle: useWearableSleepCycle ?? this.useWearableSleepCycle,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    gradualWakeEnabled: gradualWakeEnabled ?? this.gradualWakeEnabled,
    gradualWakeMinutes: gradualWakeMinutes ?? this.gradualWakeMinutes,
  );
}

class TripPlan {
  const TripPlan({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.climate,
    required this.timeZoneShift,
    required this.adjustment,
    this.country = '',
    this.city = '',
    this.lodgingAddress = '',
    this.workplace = '',
    this.transport = '',
    this.travelMinutes = 0,
    this.transfers = 0,
    this.waitMinutes = 0,
    this.nightTravel = false,
    this.sleepInTransit = false,
    this.gymAvailable = false,
    this.poolAvailable = false,
    this.roomWorkoutAvailable = true,
    this.workSchedule = '',
    this.mealPlan = '',
  });

  final String id;
  final String title;
  final String startDate;
  final String endDate;
  final String climate;
  final int timeZoneShift;
  final String adjustment;
  final String country;
  final String city;
  final String lodgingAddress;
  final String workplace;
  final String transport;
  final int travelMinutes;
  final int transfers;
  final int waitMinutes;
  final bool nightTravel;
  final bool sleepInTransit;
  final bool gymAvailable;
  final bool poolAvailable;
  final bool roomWorkoutAvailable;
  final String workSchedule;
  final String mealPlan;

  factory TripPlan.fromJson(Map<String, dynamic> json) => TripPlan(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    startDate: _string(json['startDate'], todayKey()),
    endDate: _string(json['endDate'], todayKey()),
    climate: _string(json['climate'], ''),
    timeZoneShift: _int(json['timeZoneShift'], 0),
    adjustment: _string(json['adjustment'], ''),
    country: _string(json['country'], ''),
    city: _string(json['city'], ''),
    lodgingAddress: _string(json['lodgingAddress'], ''),
    workplace: _string(json['workplace'], ''),
    transport: _string(json['transport'], ''),
    travelMinutes: _int(json['travelMinutes'], 0),
    transfers: _int(json['transfers'], 0),
    waitMinutes: _int(json['waitMinutes'], 0),
    nightTravel: _bool(json['nightTravel'], false),
    sleepInTransit: _bool(json['sleepInTransit'], false),
    gymAvailable: _bool(json['gymAvailable'], false),
    poolAvailable: _bool(json['poolAvailable'], false),
    roomWorkoutAvailable: _bool(json['roomWorkoutAvailable'], true),
    workSchedule: _string(json['workSchedule'], ''),
    mealPlan: _string(json['mealPlan'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startDate': startDate,
    'endDate': endDate,
    'climate': climate,
    'timeZoneShift': timeZoneShift,
    'adjustment': adjustment,
    'country': country,
    'city': city,
    'lodgingAddress': lodgingAddress,
    'workplace': workplace,
    'transport': transport,
    'travelMinutes': travelMinutes,
    'transfers': transfers,
    'waitMinutes': waitMinutes,
    'nightTravel': nightTravel,
    'sleepInTransit': sleepInTransit,
    'gymAvailable': gymAvailable,
    'poolAvailable': poolAvailable,
    'roomWorkoutAvailable': roomWorkoutAvailable,
    'workSchedule': workSchedule,
    'mealPlan': mealPlan,
  };

  TripPlan copyWith({
    String? title,
    String? startDate,
    String? endDate,
    String? climate,
    int? timeZoneShift,
    String? adjustment,
    String? country,
    String? city,
    String? lodgingAddress,
    String? workplace,
    String? transport,
    int? travelMinutes,
    int? transfers,
    int? waitMinutes,
    bool? nightTravel,
    bool? sleepInTransit,
    bool? gymAvailable,
    bool? poolAvailable,
    bool? roomWorkoutAvailable,
    String? workSchedule,
    String? mealPlan,
  }) => TripPlan(
    id: id,
    title: title ?? this.title,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    climate: climate ?? this.climate,
    timeZoneShift: timeZoneShift ?? this.timeZoneShift,
    adjustment: adjustment ?? this.adjustment,
    country: country ?? this.country,
    city: city ?? this.city,
    lodgingAddress: lodgingAddress ?? this.lodgingAddress,
    workplace: workplace ?? this.workplace,
    transport: transport ?? this.transport,
    travelMinutes: travelMinutes ?? this.travelMinutes,
    transfers: transfers ?? this.transfers,
    waitMinutes: waitMinutes ?? this.waitMinutes,
    nightTravel: nightTravel ?? this.nightTravel,
    sleepInTransit: sleepInTransit ?? this.sleepInTransit,
    gymAvailable: gymAvailable ?? this.gymAvailable,
    poolAvailable: poolAvailable ?? this.poolAvailable,
    roomWorkoutAvailable: roomWorkoutAvailable ?? this.roomWorkoutAvailable,
    workSchedule: workSchedule ?? this.workSchedule,
    mealPlan: mealPlan ?? this.mealPlan,
  );
}

class MedicalEvent {
  const MedicalEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.kind,
    this.severity = '',
    this.notes = '',
    this.provider = '',
    this.bodyArea = '',
    this.linkedDocumentId = '',
  });

  final String id;
  final String title;
  final String date;
  final String kind;
  final String severity;
  final String notes;
  final String provider;
  final String bodyArea;
  final String linkedDocumentId;

  factory MedicalEvent.fromJson(Map<String, dynamic> json) => MedicalEvent(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    date: _string(json['date'], todayKey()),
    kind: _string(json['kind'], 'травма'),
    severity: _string(json['severity'], ''),
    notes: _string(json['notes'], ''),
    provider: _string(json['provider'], ''),
    bodyArea: _string(json['bodyArea'], ''),
    linkedDocumentId: _string(json['linkedDocumentId'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'kind': kind,
    'severity': severity,
    'notes': notes,
    'provider': provider,
    'bodyArea': bodyArea,
    'linkedDocumentId': linkedDocumentId,
  };

  MedicalEvent copyWith({
    String? title,
    String? date,
    String? kind,
    String? severity,
    String? notes,
    String? provider,
    String? bodyArea,
    String? linkedDocumentId,
  }) => MedicalEvent(
    id: id,
    title: title ?? this.title,
    date: date ?? this.date,
    kind: kind ?? this.kind,
    severity: severity ?? this.severity,
    notes: notes ?? this.notes,
    provider: provider ?? this.provider,
    bodyArea: bodyArea ?? this.bodyArea,
    linkedDocumentId: linkedDocumentId ?? this.linkedDocumentId,
  );
}

class CareProvider {
  const CareProvider({
    required this.id,
    required this.name,
    required this.role,
    this.specialty = '',
    this.clinic = '',
    this.phone = '',
    this.address = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String role;
  final String specialty;
  final String clinic;
  final String phone;
  final String address;
  final String notes;

  factory CareProvider.fromJson(Map<String, dynamic> json) => CareProvider(
    id: _string(json['id'], newId()),
    name: _string(json['name'], ''),
    role: _string(json['role'], 'врач'),
    specialty: _string(json['specialty'], ''),
    clinic: _string(json['clinic'], ''),
    phone: _string(json['phone'], ''),
    address: _string(json['address'], ''),
    notes: _string(json['notes'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'specialty': specialty,
    'clinic': clinic,
    'phone': phone,
    'address': address,
    'notes': notes,
  };

  CareProvider copyWith({
    String? name,
    String? role,
    String? specialty,
    String? clinic,
    String? phone,
    String? address,
    String? notes,
  }) => CareProvider(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    specialty: specialty ?? this.specialty,
    clinic: clinic ?? this.clinic,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
  );
}

class VacationPeriod {
  const VacationPeriod({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.country = '',
    this.city = '',
    this.notes = '',
    this.lodging = '',
    this.climate = '',
    this.timeZone = '',
    this.restType = '',
    this.transport = '',
    this.distanceKm = 0,
    this.travelMinutes = 0,
    this.transfers = 0,
    this.waitMinutes = 0,
    this.nightTravel = false,
    this.sleepInTransit = false,
    this.gymAvailable = false,
    this.poolAvailable = false,
    this.walkingAvailable = true,
    this.alarmGroupId = '',
  });

  final String id;
  final String title;
  final String startDate;
  final String endDate;
  final String country;
  final String city;
  final String notes;
  final String lodging;
  final String climate;
  final String timeZone;
  final String restType;
  final String transport;
  final int distanceKm;
  final int travelMinutes;
  final int transfers;
  final int waitMinutes;
  final bool nightTravel;
  final bool sleepInTransit;
  final bool gymAvailable;
  final bool poolAvailable;
  final bool walkingAvailable;
  final String alarmGroupId;

  factory VacationPeriod.fromJson(Map<String, dynamic> json) => VacationPeriod(
    id: _string(json['id'], newId()),
    title: _string(json['title'], 'Отпуск'),
    startDate: _string(json['startDate'], todayKey()),
    endDate: _string(json['endDate'], todayKey()),
    country: _string(json['country'], ''),
    city: _string(json['city'], ''),
    notes: _string(json['notes'], ''),
    lodging: _string(json['lodging'], ''),
    climate: _string(json['climate'], ''),
    timeZone: _string(json['timeZone'], ''),
    restType: _string(json['restType'], ''),
    transport: _string(json['transport'], ''),
    distanceKm: _int(json['distanceKm'], 0),
    travelMinutes: _int(json['travelMinutes'], 0),
    transfers: _int(json['transfers'], 0),
    waitMinutes: _int(json['waitMinutes'], 0),
    nightTravel: _bool(json['nightTravel'], false),
    sleepInTransit: _bool(json['sleepInTransit'], false),
    gymAvailable: _bool(json['gymAvailable'], false),
    poolAvailable: _bool(json['poolAvailable'], false),
    walkingAvailable: _bool(json['walkingAvailable'], true),
    alarmGroupId: _string(json['alarmGroupId'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startDate': startDate,
    'endDate': endDate,
    'country': country,
    'city': city,
    'notes': notes,
    'lodging': lodging,
    'climate': climate,
    'timeZone': timeZone,
    'restType': restType,
    'transport': transport,
    'distanceKm': distanceKm,
    'travelMinutes': travelMinutes,
    'transfers': transfers,
    'waitMinutes': waitMinutes,
    'nightTravel': nightTravel,
    'sleepInTransit': sleepInTransit,
    'gymAvailable': gymAvailable,
    'poolAvailable': poolAvailable,
    'walkingAvailable': walkingAvailable,
    'alarmGroupId': alarmGroupId,
  };

  VacationPeriod copyWith({
    String? title,
    String? startDate,
    String? endDate,
    String? country,
    String? city,
    String? notes,
    String? lodging,
    String? climate,
    String? timeZone,
    String? restType,
    String? transport,
    int? distanceKm,
    int? travelMinutes,
    int? transfers,
    int? waitMinutes,
    bool? nightTravel,
    bool? sleepInTransit,
    bool? gymAvailable,
    bool? poolAvailable,
    bool? walkingAvailable,
    String? alarmGroupId,
  }) => VacationPeriod(
    id: id,
    title: title ?? this.title,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    country: country ?? this.country,
    city: city ?? this.city,
    notes: notes ?? this.notes,
    lodging: lodging ?? this.lodging,
    climate: climate ?? this.climate,
    timeZone: timeZone ?? this.timeZone,
    restType: restType ?? this.restType,
    transport: transport ?? this.transport,
    distanceKm: distanceKm ?? this.distanceKm,
    travelMinutes: travelMinutes ?? this.travelMinutes,
    transfers: transfers ?? this.transfers,
    waitMinutes: waitMinutes ?? this.waitMinutes,
    nightTravel: nightTravel ?? this.nightTravel,
    sleepInTransit: sleepInTransit ?? this.sleepInTransit,
    gymAvailable: gymAvailable ?? this.gymAvailable,
    poolAvailable: poolAvailable ?? this.poolAvailable,
    walkingAvailable: walkingAvailable ?? this.walkingAvailable,
    alarmGroupId: alarmGroupId ?? this.alarmGroupId,
  );
}

class WorkDuty {
  const WorkDuty({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.arrivalTime = '',
    this.restWindow = '',
    this.notes = '',
  });

  final String id;
  final String date;
  final String startTime;
  final String endTime;
  final String arrivalTime;
  final String restWindow;
  final String notes;

  factory WorkDuty.fromJson(Map<String, dynamic> json) => WorkDuty(
    id: _string(json['id'], newId()),
    date: _string(json['date'], todayKey()),
    startTime: _string(json['startTime'], ''),
    endTime: _string(json['endTime'], ''),
    arrivalTime: _string(json['arrivalTime'], ''),
    restWindow: _string(json['restWindow'], ''),
    notes: _string(json['notes'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'arrivalTime': arrivalTime,
    'restWindow': restWindow,
    'notes': notes,
  };
}

class WorkSchedule {
  const WorkSchedule({
    this.workStart = '',
    this.workEnd = '',
    this.commuteMinutes = 0,
    this.lunchStart = '',
    this.lunchEnd = '',
    this.leavesForLunch = false,
    this.lunchCommuteMinutes = 0,
    this.pattern = 'weekdays',
    this.workDays = const ['пн', 'вт', 'ср', 'чт', 'пт'],
    this.shiftCycle = '',
    this.shiftAnchorDate = '',
    this.shiftWorkDays = 1,
    this.shiftRestDays = 3,
    this.duties = const [],
    this.vacations = const [],
  });

  final String workStart;
  final String workEnd;
  final int commuteMinutes;
  final String lunchStart;
  final String lunchEnd;
  final bool leavesForLunch;
  final int lunchCommuteMinutes;
  final String pattern;
  final List<String> workDays;
  final String shiftCycle;
  final String shiftAnchorDate;
  final int shiftWorkDays;
  final int shiftRestDays;
  final List<WorkDuty> duties;
  final List<VacationPeriod> vacations;

  factory WorkSchedule.fromJson(
    Map<String, dynamic> json,
    WorkSchedule fallback,
  ) => WorkSchedule(
    workStart: _string(json['workStart'], fallback.workStart),
    workEnd: _string(json['workEnd'], fallback.workEnd),
    commuteMinutes: _int(json['commuteMinutes'], fallback.commuteMinutes),
    lunchStart: _string(json['lunchStart'], fallback.lunchStart),
    lunchEnd: _string(json['lunchEnd'], fallback.lunchEnd),
    leavesForLunch: _bool(json['leavesForLunch'], fallback.leavesForLunch),
    lunchCommuteMinutes: _int(
      json['lunchCommuteMinutes'],
      fallback.lunchCommuteMinutes,
    ),
    pattern: _string(json['pattern'], fallback.pattern),
    workDays: _stringList(json['workDays'], fallback.workDays),
    shiftCycle: _string(json['shiftCycle'], fallback.shiftCycle),
    shiftAnchorDate: _string(json['shiftAnchorDate'], fallback.shiftAnchorDate),
    shiftWorkDays: _int(json['shiftWorkDays'], fallback.shiftWorkDays),
    shiftRestDays: _int(json['shiftRestDays'], fallback.shiftRestDays),
    duties: _objectList(json['duties'], WorkDuty.fromJson),
    vacations: _objectList(json['vacations'], VacationPeriod.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'workStart': workStart,
    'workEnd': workEnd,
    'commuteMinutes': commuteMinutes,
    'lunchStart': lunchStart,
    'lunchEnd': lunchEnd,
    'leavesForLunch': leavesForLunch,
    'lunchCommuteMinutes': lunchCommuteMinutes,
    'pattern': pattern,
    'workDays': workDays,
    'shiftCycle': shiftCycle,
    'shiftAnchorDate': shiftAnchorDate,
    'shiftWorkDays': shiftWorkDays,
    'shiftRestDays': shiftRestDays,
    'duties': duties.map((item) => item.toJson()).toList(),
    'vacations': vacations.map((item) => item.toJson()).toList(),
  };

  WorkSchedule copyWith({
    String? workStart,
    String? workEnd,
    int? commuteMinutes,
    String? lunchStart,
    String? lunchEnd,
    bool? leavesForLunch,
    int? lunchCommuteMinutes,
    String? pattern,
    List<String>? workDays,
    String? shiftCycle,
    String? shiftAnchorDate,
    int? shiftWorkDays,
    int? shiftRestDays,
    List<WorkDuty>? duties,
    List<VacationPeriod>? vacations,
  }) => WorkSchedule(
    workStart: workStart ?? this.workStart,
    workEnd: workEnd ?? this.workEnd,
    commuteMinutes: commuteMinutes ?? this.commuteMinutes,
    lunchStart: lunchStart ?? this.lunchStart,
    lunchEnd: lunchEnd ?? this.lunchEnd,
    leavesForLunch: leavesForLunch ?? this.leavesForLunch,
    lunchCommuteMinutes: lunchCommuteMinutes ?? this.lunchCommuteMinutes,
    pattern: pattern ?? this.pattern,
    workDays: workDays ?? this.workDays,
    shiftCycle: shiftCycle ?? this.shiftCycle,
    shiftAnchorDate: shiftAnchorDate ?? this.shiftAnchorDate,
    shiftWorkDays: shiftWorkDays ?? this.shiftWorkDays,
    shiftRestDays: shiftRestDays ?? this.shiftRestDays,
    duties: duties ?? this.duties,
    vacations: vacations ?? this.vacations,
  );
}

class ActivityReminderSettings {
  const ActivityReminderSettings({
    this.warmupEnabled = true,
    this.waterEnabled = true,
    this.medicineEnabled = true,
    this.warmupIntervalMinutes = 60,
    this.waterIntervalMinutes = 90,
    this.activeMinutesTarget = 45,
    this.quietStart = '22:00',
    this.quietEnd = '07:00',
  });

  final bool warmupEnabled;
  final bool waterEnabled;
  final bool medicineEnabled;
  final int warmupIntervalMinutes;
  final int waterIntervalMinutes;
  final int activeMinutesTarget;
  final String quietStart;
  final String quietEnd;

  factory ActivityReminderSettings.fromJson(
    Map<String, dynamic> json,
    ActivityReminderSettings fallback,
  ) => ActivityReminderSettings(
    warmupEnabled: _bool(json['warmupEnabled'], fallback.warmupEnabled),
    waterEnabled: _bool(json['waterEnabled'], fallback.waterEnabled),
    medicineEnabled: _bool(json['medicineEnabled'], fallback.medicineEnabled),
    warmupIntervalMinutes: _int(
      json['warmupIntervalMinutes'],
      fallback.warmupIntervalMinutes,
    ),
    waterIntervalMinutes: _int(
      json['waterIntervalMinutes'],
      fallback.waterIntervalMinutes,
    ),
    activeMinutesTarget: _int(
      json['activeMinutesTarget'],
      fallback.activeMinutesTarget,
    ),
    quietStart: _string(json['quietStart'], fallback.quietStart),
    quietEnd: _string(json['quietEnd'], fallback.quietEnd),
  );

  Map<String, dynamic> toJson() => {
    'warmupEnabled': warmupEnabled,
    'waterEnabled': waterEnabled,
    'medicineEnabled': medicineEnabled,
    'warmupIntervalMinutes': warmupIntervalMinutes,
    'waterIntervalMinutes': waterIntervalMinutes,
    'activeMinutesTarget': activeMinutesTarget,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
  };

  ActivityReminderSettings copyWith({
    bool? warmupEnabled,
    bool? waterEnabled,
    bool? medicineEnabled,
    int? warmupIntervalMinutes,
    int? waterIntervalMinutes,
    int? activeMinutesTarget,
    String? quietStart,
    String? quietEnd,
  }) => ActivityReminderSettings(
    warmupEnabled: warmupEnabled ?? this.warmupEnabled,
    waterEnabled: waterEnabled ?? this.waterEnabled,
    medicineEnabled: medicineEnabled ?? this.medicineEnabled,
    warmupIntervalMinutes: warmupIntervalMinutes ?? this.warmupIntervalMinutes,
    waterIntervalMinutes: waterIntervalMinutes ?? this.waterIntervalMinutes,
    activeMinutesTarget: activeMinutesTarget ?? this.activeMinutesTarget,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
  );
}

class OfflineMapPack {
  const OfflineMapPack({
    required this.id,
    required this.title,
    required this.scope,
    required this.country,
    required this.region,
    required this.city,
    required this.minZoom,
    required this.maxZoom,
    required this.downloadedAt,
    required this.tileCount,
    required this.storagePath,
  });

  final String id;
  final String title;
  final String scope;
  final String country;
  final String region;
  final String city;
  final int minZoom;
  final int maxZoom;
  final String downloadedAt;
  final int tileCount;
  final String storagePath;

  factory OfflineMapPack.fromJson(Map<String, dynamic> json) => OfflineMapPack(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    scope: _string(json['scope'], 'city'),
    country: _string(json['country'], ''),
    region: _string(json['region'], ''),
    city: _string(json['city'], ''),
    minZoom: _int(json['minZoom'], 11),
    maxZoom: _int(json['maxZoom'], 14),
    downloadedAt: _string(json['downloadedAt'], ''),
    tileCount: _int(json['tileCount'], 0),
    storagePath: _string(json['storagePath'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'scope': scope,
    'country': country,
    'region': region,
    'city': city,
    'minZoom': minZoom,
    'maxZoom': maxZoom,
    'downloadedAt': downloadedAt,
    'tileCount': tileCount,
    'storagePath': storagePath,
  };
}

class BleCharacteristicMapping {
  const BleCharacteristicMapping({
    required this.id,
    required this.title,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.metric,
    required this.parser,
    this.unit = '',
    this.reference = '',
    this.scale = 1,
    this.offset = 0,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String serviceUuid;
  final String characteristicUuid;
  final String metric;
  final String parser;
  final String unit;
  final String reference;
  final double scale;
  final double offset;
  final bool enabled;

  factory BleCharacteristicMapping.fromJson(Map<String, dynamic> json) =>
      BleCharacteristicMapping(
        id: _string(json['id'], newId()),
        title: _string(json['title'], ''),
        serviceUuid: _string(json['serviceUuid'], ''),
        characteristicUuid: _string(json['characteristicUuid'], ''),
        metric: _string(json['metric'], 'customLab'),
        parser: _string(json['parser'], 'uint8'),
        unit: _string(json['unit'], ''),
        reference: _string(json['reference'], ''),
        scale: _double(json['scale'], 1),
        offset: _double(json['offset'], 0),
        enabled: _bool(json['enabled'], true),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'serviceUuid': serviceUuid,
    'characteristicUuid': characteristicUuid,
    'metric': metric,
    'parser': parser,
    'unit': unit,
    'reference': reference,
    'scale': scale,
    'offset': offset,
    'enabled': enabled,
  };

  BleCharacteristicMapping copyWith({
    String? title,
    String? serviceUuid,
    String? characteristicUuid,
    String? metric,
    String? parser,
    String? unit,
    String? reference,
    double? scale,
    double? offset,
    bool? enabled,
  }) {
    return BleCharacteristicMapping(
      id: id,
      title: title ?? this.title,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      characteristicUuid: characteristicUuid ?? this.characteristicUuid,
      metric: metric ?? this.metric,
      parser: parser ?? this.parser,
      unit: unit ?? this.unit,
      reference: reference ?? this.reference,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      enabled: enabled ?? this.enabled,
    );
  }
}

class BleWriteCommand {
  const BleWriteCommand({
    required this.id,
    required this.title,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.payloadHex,
    this.withoutResponse = false,
    this.runBeforeSync = true,
    this.delayMs = 250,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String serviceUuid;
  final String characteristicUuid;
  final String payloadHex;
  final bool withoutResponse;
  final bool runBeforeSync;
  final int delayMs;
  final bool enabled;

  factory BleWriteCommand.fromJson(Map<String, dynamic> json) =>
      BleWriteCommand(
        id: _string(json['id'], newId()),
        title: _string(json['title'], ''),
        serviceUuid: _string(json['serviceUuid'], ''),
        characteristicUuid: _string(json['characteristicUuid'], ''),
        payloadHex: _string(json['payloadHex'], ''),
        withoutResponse: _bool(json['withoutResponse'], false),
        runBeforeSync: _bool(json['runBeforeSync'], true),
        delayMs: _int(json['delayMs'], 250),
        enabled: _bool(json['enabled'], true),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'serviceUuid': serviceUuid,
    'characteristicUuid': characteristicUuid,
    'payloadHex': payloadHex,
    'withoutResponse': withoutResponse,
    'runBeforeSync': runBeforeSync,
    'delayMs': delayMs,
    'enabled': enabled,
  };

  BleWriteCommand copyWith({
    String? title,
    String? serviceUuid,
    String? characteristicUuid,
    String? payloadHex,
    bool? withoutResponse,
    bool? runBeforeSync,
    int? delayMs,
    bool? enabled,
  }) {
    return BleWriteCommand(
      id: id,
      title: title ?? this.title,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      characteristicUuid: characteristicUuid ?? this.characteristicUuid,
      payloadHex: payloadHex ?? this.payloadHex,
      withoutResponse: withoutResponse ?? this.withoutResponse,
      runBeforeSync: runBeforeSync ?? this.runBeforeSync,
      delayMs: delayMs ?? this.delayMs,
      enabled: enabled ?? this.enabled,
    );
  }
}

class DeviceConnection {
  const DeviceConnection({
    required this.id,
    required this.title,
    required this.type,
    required this.enabled,
    required this.lastSync,
    required this.permissions,
    this.deviceId = '',
    this.vendor = '',
    this.model = '',
    this.protocol = 'BLE',
    this.services = const [],
    this.features = const [],
    this.bleMappings = const [],
    this.bleCommands = const [],
    this.status = 'disconnected',
    this.rssi,
    this.batteryPercent,
    this.lastError = '',
  });

  final String id;
  final String title;
  final String type;
  final bool enabled;
  final String lastSync;
  final String permissions;
  final String deviceId;
  final String vendor;
  final String model;
  final String protocol;
  final List<String> services;
  final List<String> features;
  final List<BleCharacteristicMapping> bleMappings;
  final List<BleWriteCommand> bleCommands;
  final String status;
  final int? rssi;
  final int? batteryPercent;
  final String lastError;

  factory DeviceConnection.fromJson(Map<String, dynamic> json) =>
      DeviceConnection(
        id: _string(json['id'], newId()),
        title: _string(json['title'], ''),
        type: _string(json['type'], ''),
        enabled: _bool(json['enabled'], false),
        lastSync: _string(json['lastSync'], ''),
        permissions: _string(json['permissions'], ''),
        deviceId: _string(json['deviceId'], ''),
        vendor: _string(json['vendor'], ''),
        model: _string(json['model'], ''),
        protocol: _string(json['protocol'], 'BLE'),
        services: _stringList(json['services'], const []),
        features: _stringList(json['features'], const []),
        bleMappings: _objectList(
          json['bleMappings'] ?? json['mappings'],
          BleCharacteristicMapping.fromJson,
        ),
        bleCommands: _objectList(json['bleCommands'], BleWriteCommand.fromJson),
        status: _string(json['status'], 'disconnected'),
        rssi: _nullableInt(json['rssi']),
        batteryPercent: _nullableInt(json['batteryPercent']),
        lastError: _string(json['lastError'], ''),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'enabled': enabled,
    'lastSync': lastSync,
    'permissions': permissions,
    'deviceId': deviceId,
    'vendor': vendor,
    'model': model,
    'protocol': protocol,
    'services': services,
    'features': features,
    'bleMappings': bleMappings.map((item) => item.toJson()).toList(),
    'bleCommands': bleCommands.map((item) => item.toJson()).toList(),
    'status': status,
    'rssi': rssi,
    'batteryPercent': batteryPercent,
    'lastError': lastError,
  };

  DeviceConnection copyWith({
    String? title,
    String? type,
    bool? enabled,
    String? lastSync,
    String? permissions,
    String? deviceId,
    String? vendor,
    String? model,
    String? protocol,
    List<String>? services,
    List<String>? features,
    List<BleCharacteristicMapping>? bleMappings,
    List<BleWriteCommand>? bleCommands,
    String? status,
    int? rssi,
    int? batteryPercent,
    String? lastError,
  }) {
    return DeviceConnection(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      lastSync: lastSync ?? this.lastSync,
      permissions: permissions ?? this.permissions,
      deviceId: deviceId ?? this.deviceId,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      protocol: protocol ?? this.protocol,
      services: services ?? this.services,
      features: features ?? this.features,
      bleMappings: bleMappings ?? this.bleMappings,
      bleCommands: bleCommands ?? this.bleCommands,
      status: status ?? this.status,
      rssi: rssi ?? this.rssi,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      lastError: lastError ?? this.lastError,
    );
  }
}

class HealthDocument {
  const HealthDocument({
    required this.id,
    required this.title,
    required this.kind,
    required this.date,
    required this.locked,
    required this.notes,
    this.filePath = '',
    this.tags = const [],
    this.linkedCondition = '',
    this.linkedMedicationId = '',
    this.linkedDoctor = '',
    this.searchText = '',
    this.fileName = '',
  });

  final String id;
  final String title;
  final String kind;
  final String date;
  final bool locked;
  final String notes;
  final String filePath;
  final List<String> tags;
  final String linkedCondition;
  final String linkedMedicationId;
  final String linkedDoctor;
  final String searchText;
  final String fileName;

  factory HealthDocument.fromJson(Map<String, dynamic> json) => HealthDocument(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    kind: _string(json['kind'], ''),
    date: _string(json['date'], todayKey()),
    locked: _bool(json['locked'], true),
    notes: _string(json['notes'], ''),
    filePath: _string(json['filePath'], ''),
    tags: _stringList(json['tags'], const []),
    linkedCondition: _string(json['linkedCondition'], ''),
    linkedMedicationId: _string(json['linkedMedicationId'], ''),
    linkedDoctor: _string(json['linkedDoctor'], ''),
    searchText: _string(json['searchText'], ''),
    fileName: _string(json['fileName'], ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'date': date,
    'locked': locked,
    'notes': notes,
    'filePath': filePath,
    'tags': tags,
    'linkedCondition': linkedCondition,
    'linkedMedicationId': linkedMedicationId,
    'linkedDoctor': linkedDoctor,
    'searchText': searchText,
    'fileName': fileName,
  };

  HealthDocument copyWith({
    String? title,
    String? kind,
    String? date,
    bool? locked,
    String? notes,
    String? filePath,
    List<String>? tags,
    String? linkedCondition,
    String? linkedMedicationId,
    String? linkedDoctor,
    String? searchText,
    String? fileName,
  }) => HealthDocument(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    date: date ?? this.date,
    locked: locked ?? this.locked,
    notes: notes ?? this.notes,
    filePath: filePath ?? this.filePath,
    tags: tags ?? this.tags,
    linkedCondition: linkedCondition ?? this.linkedCondition,
    linkedMedicationId: linkedMedicationId ?? this.linkedMedicationId,
    linkedDoctor: linkedDoctor ?? this.linkedDoctor,
    searchText: searchText ?? this.searchText,
    fileName: fileName ?? this.fileName,
  );
}

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.time,
    required this.category,
    required this.done,
    this.date = '',
  });

  final String id;
  final String title;
  final String time;
  final String category;
  final bool done;
  final String date;

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    id: _string(json['id'], newId()),
    title: _string(json['title'], ''),
    time: _string(json['time'], ''),
    category: _string(json['category'], ''),
    done: _bool(json['done'], false),
    date: _string(json['date'], todayKey()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'time': time,
    'category': category,
    'done': done,
    'date': date,
  };

  ReminderItem copyWith({
    String? title,
    String? time,
    String? category,
    bool? done,
    String? date,
  }) => ReminderItem(
    id: id,
    title: title ?? this.title,
    time: time ?? this.time,
    category: category ?? this.category,
    done: done ?? this.done,
    date: date ?? this.date,
  );
}

class RecognitionCandidate {
  const RecognitionCandidate({
    required this.id,
    required this.source,
    required this.title,
    required this.confidence,
    required this.requiresMedicalReview,
    this.filePath = '',
    this.kind = 'image',
    this.createdAt = '',
    this.metadata = const {},
  });

  final String id;
  final String source;
  final String title;
  final double confidence;
  final bool requiresMedicalReview;
  final String filePath;
  final String kind;
  final String createdAt;
  final Map<String, String> metadata;

  factory RecognitionCandidate.fromJson(Map<String, dynamic> json) =>
      RecognitionCandidate(
        id: _string(json['id'], newId()),
        source: _string(json['source'], ''),
        title: _string(json['title'], ''),
        confidence: _double(json['confidence'], 0),
        requiresMedicalReview: _bool(json['requiresMedicalReview'], true),
        filePath: _string(json['filePath'], ''),
        kind: _string(json['kind'], 'image'),
        createdAt: _string(json['createdAt'], todayKey()),
        metadata: _stringMap(json['metadata']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'title': title,
    'confidence': confidence,
    'requiresMedicalReview': requiresMedicalReview,
    'filePath': filePath,
    'kind': kind,
    'createdAt': createdAt,
    'metadata': metadata,
  };
}

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.createdAt,
    required this.role,
    required this.text,
    this.relatedSection = '',
  });

  final String id;
  final String createdAt;
  final String role;
  final String text;
  final String relatedSection;

  factory AssistantMessage.fromJson(Map<String, dynamic> json) =>
      AssistantMessage(
        id: _string(json['id'], newId()),
        createdAt: _string(json['createdAt'], DateTime.now().toIso8601String()),
        role: _string(json['role'], 'assistant'),
        text: _string(json['text'], ''),
        relatedSection: _string(json['relatedSection'], ''),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt,
    'role': role,
    'text': text,
    'relatedSection': relatedSection,
  };
}

class CustomOption {
  const CustomOption({
    required this.id,
    required this.group,
    required this.label,
    required this.metadata,
  });

  final String id;
  final String group;
  final String label;
  final Map<String, String> metadata;

  factory CustomOption.fromJson(Map<String, dynamic> json) => CustomOption(
    id: _string(json['id'], newId()),
    group: _string(json['group'], ''),
    label: _string(json['label'], ''),
    metadata: _stringMap(json['metadata']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'group': group,
    'label': label,
    'metadata': metadata,
  };
}

List<DailyMetrics> _upsertDailyMetric(
  List<DailyMetrics> source,
  DailyMetrics metric,
) {
  final next = [metric, ...source.where((item) => item.date != metric.date)];
  next.sort((a, b) => b.date.compareTo(a.date));
  return next;
}

double _bounded(double value) => math.max(0, math.min(1, value));

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

String _string(Object? value, String fallback) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return fallback;
}

int _int(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _int(value, 0);
}

double _double(Object? value, double fallback) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
  }
  return fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  return _double(value, 0);
}

bool _bool(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  return fallback;
}

List<String> _stringList(Object? value, List<String> fallback) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return List<String>.from(fallback);
}

Map<String, String> _stringMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', '$item'));
  }
  return const {};
}

List<T> _objectList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) factory,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Map>()
      .map((item) => factory(Map<String, dynamic>.from(item)))
      .toList();
}
