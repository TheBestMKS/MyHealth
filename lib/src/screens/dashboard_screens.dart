part of '../screens.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onSelect,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;
  final SectionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    final locale = state.localeCode;
    final color = Theme.of(context).colorScheme;
    final todayDistanceMeters = state.workouts
        .where((item) => item.scheduledDate == state.today.date)
        .fold<double>(0, (sum, item) => sum + item.distanceMeters);
    return PageBand(
      title: AppText.get(locale, 'today'),
      subtitle:
          '${state.profile.name}, ${formatDisplayDate(state.today.date, state.settings)} · ${state.profile.goal}',
      trailing: FilledButton.icon(
        onPressed: () =>
            showUniversalCaptureSheet(context, state, onChanged, onSelect),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      children: [
        CompactGaugeStrip(
          children: [
            CompactGauge(
              label: AppText.get(locale, 'readiness'),
              value: '${state.readinessScore}/100',
              icon: Icons.bolt_outlined,
              color: Colors.teal,
              progress: state.readinessScore / 100,
              onTap: () => onSelect(AppSection.analytics),
            ),
            CompactGauge(
              label: AppText.get(locale, 'energy'),
              value: '${state.energyScore}/100',
              icon: Icons.battery_charging_full_outlined,
              color: Colors.indigo,
              progress: state.energyScore / 100,
              onTap: () => onSelect(AppSection.analytics),
            ),
            CompactGauge(
              label: AppText.get(locale, 'sleepHours'),
              value: '${state.today.sleepHours.toStringAsFixed(1)} ч',
              icon: Icons.bedtime_outlined,
              color: Colors.blue,
              progress: state.today.sleepHours / 8,
              onTap: () => onSelect(AppSection.sleep),
            ),
            CompactGauge(
              label: AppText.get(locale, 'steps'),
              value: '${state.today.steps}',
              icon: Icons.directions_walk_outlined,
              color: Colors.green,
              progress: state.today.steps / 9000,
              onTap: () => onSelect(AppSection.workouts),
            ),
            CompactGauge(
              label: AppText.get(locale, 'water'),
              value: '${state.today.waterLiters.toStringAsFixed(1)} л',
              icon: Icons.water_drop_outlined,
              color: Colors.cyan,
              progress: state.today.waterLiters / 2.4,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ResponsiveGrid(
          minTileWidth: 190,
          children: [
            MetricCard(
              title: 'Активный расход',
              value: '${state.today.activeCalories} ккал',
              subtitle:
                  'расстояние ${formatDistance(todayDistanceMeters, state.settings)}',
              icon: Icons.directions_run_outlined,
              color: Colors.red,
              onTap: () => onSelect(AppSection.analytics),
            ),
            if (state.settings.advancedMode) ...[
              MetricCard(
                title: 'Базовый расход',
                value: '${state.profile.restingCaloriesBurnedSoFar()} ккал',
                subtitle:
                    'накоплено за текущие сутки из ${state.profile.basalMetabolicRate.round()} ккал',
                icon: Icons.local_fire_department_outlined,
                color: Colors.deepOrange,
                progress: state.profile.basalMetabolicRate <= 0
                    ? 0
                    : state.profile.restingCaloriesBurnedSoFar() /
                          state.profile.basalMetabolicRate,
              ),
              MetricCard(
                title: 'Жир',
                value: state.profile.estimatedBodyFatPercent == 0
                    ? 'нет данных'
                    : '${state.profile.estimatedBodyFatPercent.toStringAsFixed(1)}%',
                subtitle: 'по росту, весу, возрасту и полу',
                icon: Icons.percent_outlined,
                color: Colors.purple,
                progress: state.profile.estimatedBodyFatPercent / 45,
              ),
              MetricCard(
                title: AppText.get(locale, 'confirmations'),
                value: '${state.confirmationQueue.length}',
                subtitle: 'OCR, фото еды, AI',
                icon: Icons.fact_check_outlined,
                color: Colors.orange,
                progress: state.confirmationQueue.isEmpty ? 1 : 0.35,
                onTap: () => onSelect(AppSection.foodPhoto),
              ),
            ],
          ],
        ),
        const MedicalDisclaimerBanner(),
        IntegratedPlanPanel(state: state, onSelect: onSelect),
        SectionTitle('Мотивация'),
        InfoTile(
          icon: Icons.emoji_events_outlined,
          title: state.motivationMessage,
          subtitle: 'Режим ${state.settings.motivationStrictness} из 4',
          onTap: () => onSelect(AppSection.workouts),
        ),
        SectionTitle('Погода и климат'),
        _weatherTodayBlock(state),
        SectionTitle(AppText.get(locale, 'aiSummary')),
        ...state.insights.map(
          (item) => InfoTile(
            icon: Icons.auto_awesome_outlined,
            title: item,
            subtitle: 'Расчёт по данным профиля и сегодняшним отметкам.',
          ),
        ),
        SectionTitle(
          AppText.get(locale, 'reminders'),
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Добавить напоминание',
            onPressed: () => _editReminder(context, state, onChanged),
            icon: const Icon(Icons.add_alert_outlined),
          ),
        ),
        ...state.reminders
            .take(4)
            .map(
              (item) => InfoTile(
                icon: item.done
                    ? Icons.check_circle_outline
                    : Icons.notifications_outlined,
                title: item.title,
                subtitle: '${item.category} · ${item.time}',
                onTap: () => _editReminder(context, state, onChanged, item),
                onLongPress: () => _confirmDelete(
                  context,
                  title: item.title,
                  onDelete: () =>
                      onChanged(_deleteReminderFromState(state, item)),
                ),
                trailing: Checkbox(
                  value: item.done,
                  onChanged: (value) {
                    final reminders = state.reminders
                        .map(
                          (candidate) => candidate.id == item.id
                              ? candidate.copyWith(done: value)
                              : candidate,
                        )
                        .toList();
                    onChanged(state.copyWith(reminders: reminders));
                  },
                ),
              ),
            ),
        SectionTitle('Быстрые действия'),
        ActionRow(
          children: [
            ActionChip(
              avatar: const Icon(Icons.medication_outlined),
              label: const Text('Отметить лекарства'),
              onPressed: () {
                final additions = state.medications
                    .where(
                      (medication) => !state.medicationTakenOnDate(
                        medication,
                        state.today.date,
                      ),
                    )
                    .map(
                      (medication) => MedicationIntake(
                        id: newId(),
                        medicationId: medication.id,
                        medicationName: medication.name,
                        dose: medication.dose,
                        date: state.today.date,
                        time: '',
                        status: 'принято',
                        notes: 'Быстрая отметка за сегодня.',
                      ),
                    );
                onChanged(
                  state.copyWith(
                    medicationIntakes: [
                      ...additions,
                      ...state.medicationIntakes,
                    ],
                    today: state.today.copyWith(medicationTaken: true),
                  ),
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.restaurant_outlined),
              label: const Text('Добавить еду'),
              onPressed: () => onSelect(AppSection.nutrition),
            ),
            ActionChip(
              avatar: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Отчёт врачу'),
              onPressed: () => onSelect(AppSection.documents),
            ),
            ActionChip(
              avatar: Icon(Icons.warning_amber_outlined, color: color.error),
              label: const Text('Проверить симптомы'),
              onPressed: () => onSelect(AppSection.symptoms),
            ),
          ],
        ),
      ],
    );
  }
}

class HealthScreen extends StatelessWidget {
  const HealthScreen({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onSelect,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;
  final SectionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'health'),
      subtitle: 'Сводка состояния, рисков, лекарств и данных для проверки',
      children: [
        const MedicalDisclaimerBanner(),
        ResponsiveGrid(
          children: [
            MetricCard(
              title: 'Вес',
              value: formatWeight(state.today.weightKg, state.settings),
              subtitle:
                  'рост ${formatHeight(state.profile.heightCm, state.settings)}',
              icon: Icons.monitor_weight_outlined,
              color: Colors.teal,
              onTap: () => showQuickAddDialog(context, state, onChanged),
            ),
            MetricCard(
              title: 'Жир',
              value: state.profile.estimatedBodyFatPercent == 0
                  ? 'нет данных'
                  : '${state.profile.estimatedBodyFatPercent.toStringAsFixed(1)}%',
              subtitle: 'формула BMI + возраст + пол',
              icon: Icons.percent_outlined,
              color: Colors.purple,
              progress: state.profile.estimatedBodyFatPercent / 45,
              onTap: () => onSelect(AppSection.profile),
            ),
            MetricCard(
              title: 'Базовый обмен',
              value: '${state.profile.basalMetabolicRate.round()} ккал',
              subtitle:
                  'сейчас учтено ${state.profile.restingCaloriesBurnedSoFar()} ккал',
              icon: Icons.local_fire_department_outlined,
              color: Colors.deepOrange,
              onTap: () => onSelect(AppSection.profile),
            ),
            MetricCard(
              title: 'Открытые вопросы',
              value: '${state.openSafetyItems}',
              subtitle: 'анализы и AI-распознавания',
              icon: Icons.verified_user_outlined,
              color: Colors.orange,
              progress: state.openSafetyItems == 0 ? 1 : 0.4,
              onTap: () => onSelect(AppSection.labs),
            ),
            MetricCard(
              title: 'Лекарства',
              value:
                  '${state.medicationTakenCount(state.today.date)}/${state.medications.length}',
              subtitle: 'отмечено сегодня',
              icon: Icons.medication_outlined,
              color: Colors.indigo,
              progress: state.medications.isEmpty
                  ? 1
                  : state.medicationTakenCount(state.today.date) /
                        state.medications.length,
              onTap: () => onSelect(AppSection.medicines),
            ),
            MetricCard(
              title: 'Симптомы',
              value:
                  '${state.symptomNotes.length + state.today.symptoms.length}',
              subtitle: 'заметки и дневник дня',
              icon: Icons.healing_outlined,
              color: Colors.red,
              onTap: () => onSelect(AppSection.symptoms),
            ),
          ],
        ),
        SectionTitle('Медицинские данные'),
        InfoTile(
          icon: Icons.badge_outlined,
          title: 'Медицинская карта',
          subtitle:
              '${state.chronicConditions.length} состояний, ${state.allergies.length} аллергии, ${state.contraindications.length} ограничений',
          onTap: () => onSelect(AppSection.medicalCard),
        ),
        InfoTile(
          icon: Icons.science_outlined,
          title: 'Последние анализы',
          subtitle: state.labResults
              .map((item) => item.marker)
              .take(3)
              .join(', '),
          onTap: () => onSelect(AppSection.labs),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onSelect,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;
  final SectionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final schedule = state.workSchedule;
    final activity = state.activityReminders;
    return PageBand(
      title: AppText.get(state.localeCode, 'profile'),
      subtitle: 'Личные данные, цели, рабочий график и напоминания',
      trailing: FilledButton.icon(
        onPressed: () => onChanged(state.copyWith(onboardingComplete: false)),
        icon: const Icon(Icons.restart_alt_outlined),
        label: const Text('Запустить мастер'),
      ),
      children: [
        ResponsiveGrid(
          children: [
            MetricCard(
              title: profile.name.isEmpty ? 'Пользователь' : profile.name,
              value: profile.age == 0
                  ? 'возраст не указан'
                  : '${profile.age} лет',
              subtitle:
                  '${formatDisplayDate(profile.birthDate, state.settings)} · ${profile.gender.isEmpty ? 'пол не указан' : profile.gender}',
              icon: Icons.person_outline,
              color: Colors.teal,
              onTap: () => _editProfile(context, state, onChanged),
            ),
            MetricCard(
              title: 'Цели',
              value: '${profile.trainingGoals.length}',
              subtitle: profile.trainingGoals.isEmpty
                  ? (profile.goal.isEmpty ? 'не выбраны' : profile.goal)
                  : profile.trainingGoals.join(', '),
              icon: Icons.flag_outlined,
              color: Colors.indigo,
              onTap: () => _editProfile(context, state, onChanged),
            ),
            MetricCard(
              title: 'Жир',
              value: profile.estimatedBodyFatPercent == 0
                  ? 'нет данных'
                  : '${profile.estimatedBodyFatPercent.toStringAsFixed(1)}%',
              subtitle:
                  'рост ${formatHeight(profile.heightCm, state.settings)} · вес ${formatWeight(profile.weightKg, state.settings)}',
              icon: Icons.percent_outlined,
              color: Colors.purple,
            ),
            MetricCard(
              title: 'Базовый расход',
              value: '${profile.restingCaloriesBurnedSoFar()} ккал',
              subtitle:
                  'из ${profile.basalMetabolicRate.round()} ккал за сутки',
              icon: Icons.local_fire_department_outlined,
              color: Colors.deepOrange,
            ),
          ],
        ),
        SectionTitle('Место и климат'),
        InfoTile(
          icon: Icons.public_outlined,
          title: profile.city.isEmpty
              ? 'Место не выбрано'
              : '${profile.country}, ${profile.city}',
          subtitle: [
            profile.climate,
            if (profile.timeZone.isNotEmpty) profile.timeZone,
            if (profile.airQuality.isNotEmpty) 'воздух: ${profile.airQuality}',
            if (profile.humidityPercent > 0)
              'влажность: ${profile.humidityPercent}%',
          ].where((item) => item.isNotEmpty).join(' · '),
          onTap: () => onSelect(AppSection.climate),
        ),
        InfoTile(
          icon: Icons.location_on_outlined,
          title: 'Контекст дома и работы',
          subtitle:
              'Дом: ${profile.homeLatitude == null ? 'не задан' : 'сохранён'} · '
              'работа: ${profile.workLatitude == null ? 'не задана' : 'сохранена'} · '
              'радиус ${profile.placeRadiusMeters} м',
          onTap: () => _editActivityPlaces(context, state, onChanged),
        ),
        SectionTitle('Напоминания активности'),
        InfoTile(
          icon: Icons.notifications_active_outlined,
          title: 'Разминка, вода и лекарства',
          subtitle:
              'Разминка: ${activity.warmupEnabled ? 'вкл.' : 'выкл.'} каждые ${activity.warmupIntervalMinutes} мин · вода: ${activity.waterEnabled ? 'вкл.' : 'выкл.'} каждые ${activity.waterIntervalMinutes} мин · тихий режим ${activity.quietStart}-${activity.quietEnd}',
          onTap: () => _editActivityReminders(context, state, onChanged),
        ),
        SectionTitle('Работа и отдых'),
        InfoTile(
          icon: Icons.work_outline,
          title: 'Рабочий график',
          subtitle:
              '${schedule.workStart.isEmpty ? 'начало не указано' : schedule.workStart} - ${schedule.workEnd.isEmpty ? 'окончание не указано' : schedule.workEnd} · дорога ${schedule.commuteMinutes} мин · обед ${schedule.lunchStart}-${schedule.lunchEnd}\n'
              '${schedule.pattern == 'shift' ? '${schedule.shiftWorkDays} раб. / ${schedule.shiftRestDays} отд. с ${formatDisplayDate(schedule.shiftAnchorDate, state.settings)}' : schedule.workDays.join(', ')} · дежурств: ${schedule.duties.length}',
          onTap: () => _editWorkSchedule(context, state, onChanged),
        ),
        ...schedule.duties
            .take(6)
            .map(
              (duty) => InfoTile(
                icon: Icons.admin_panel_settings_outlined,
                title:
                    'Дежурство ${formatDisplayDate(duty.date, state.settings)}',
                subtitle:
                    '${duty.startTime}-${duty.endTime} · прибытие ${duty.arrivalTime}\nОтдых: ${duty.restWindow}\n${duty.notes}',
                onLongPress: () => _confirmDelete(
                  context,
                  title:
                      'Дежурство ${formatDisplayDate(duty.date, state.settings)}',
                  onDelete: () => onChanged(
                    state.copyWith(
                      workSchedule: schedule.copyWith(
                        duties: schedule.duties
                            .where((item) => item.id != duty.id)
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        InfoTile(
          icon: Icons.beach_access_outlined,
          title: 'Отпуска',
          subtitle: schedule.vacations.isEmpty
              ? 'Отпуск пока не запланирован'
              : '${schedule.vacations.length}: ${schedule.vacations.map((item) => item.title).take(3).join(', ')}',
          onTap: () => _editVacationPeriod(context, state, onChanged),
        ),
        ...schedule.vacations
            .take(6)
            .map(
              (vacation) => InfoTile(
                icon: Icons.flight_takeoff_outlined,
                title: vacation.title,
                subtitle:
                    '${formatDisplayDate(vacation.startDate, state.settings)} - ${formatDisplayDate(vacation.endDate, state.settings)} · ${vacation.country} ${vacation.city}\n${vacation.notes}',
                onTap: () =>
                    _editVacationPeriod(context, state, onChanged, vacation),
                onLongPress: () => _confirmDelete(
                  context,
                  title: vacation.title,
                  onDelete: () => onChanged(
                    state.copyWith(
                      workSchedule: schedule.copyWith(
                        vacations: schedule.vacations
                            .where((item) => item.id != vacation.id)
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ActionRow(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _editProfile(context, state, onChanged),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Личные данные'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _editWorkSchedule(context, state, onChanged),
              icon: const Icon(Icons.work_history_outlined),
              label: const Text('График работы'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => onSelect(AppSection.medicalCard),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Медкарта'),
            ),
          ],
        ),
      ],
    );
  }
}
