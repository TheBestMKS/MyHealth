part of '../screens.dart';

class MedicalCardScreen extends StatelessWidget {
  const MedicalCardScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'medicalCard'),
      subtitle: 'Профиль, хронические состояния, аллергии и противопоказания',
      children: [
        const MedicalDisclaimerBanner(),
        ResponsiveGrid(
          children: [
            MetricCard(
              title: state.profile.name,
              value: '${state.profile.age} лет',
              subtitle:
                  '${formatHeight(state.profile.heightCm, state.settings)} · ${state.profile.city}',
              icon: Icons.person_outline,
              color: Colors.teal,
              onTap: () => _editProfile(context, state, onChanged),
            ),
            MetricCard(
              title: 'Климат',
              value: state.profile.climate,
              subtitle: state.profile.activityLevel,
              icon: Icons.wb_sunny_outlined,
              color: Colors.amber,
            ),
          ],
        ),
        _stringListBlock(
          context,
          title: 'Хронические состояния',
          icon: Icons.favorite_border,
          values: state.chronicConditions,
          onAddPressed: () => _addCatalogListItem(
            context,
            state,
            onChanged,
            title: 'Хронические состояния',
            group: 'conditions',
            options: _conditionOptions,
            values: state.chronicConditions,
            addToState: (nextState, value) => nextState.copyWith(
              chronicConditions: [...nextState.chronicConditions, value],
            ),
          ),
          onAdd: (value) => onChanged(
            state.copyWith(
              chronicConditions: [...state.chronicConditions, value],
            ),
          ),
          onRemove: (value) => onChanged(
            state.copyWith(
              chronicConditions: _removeFirstString(
                state.chronicConditions,
                value,
              ),
            ),
          ),
        ),
        _stringListBlock(
          context,
          title: 'Аллергии',
          icon: Icons.air_outlined,
          values: state.allergies,
          onAddPressed: () => _addCatalogListItem(
            context,
            state,
            onChanged,
            title: 'Аллергии',
            group: 'allergies',
            options: _allergyOptions,
            values: state.allergies,
            addToState: (nextState, value) =>
                nextState.copyWith(allergies: [...nextState.allergies, value]),
          ),
          onAdd: (value) =>
              onChanged(state.copyWith(allergies: [...state.allergies, value])),
          onRemove: (value) => onChanged(
            state.copyWith(
              allergies: _removeFirstString(state.allergies, value),
            ),
          ),
        ),
        _stringListBlock(
          context,
          title: 'Противопоказания',
          icon: Icons.do_not_disturb_alt_outlined,
          values: state.contraindications,
          onAddPressed: () => _addCatalogListItem(
            context,
            state,
            onChanged,
            title: 'Противопоказания',
            group: 'contraindications',
            options: _contraindicationOptions,
            values: state.contraindications,
            addToState: (nextState, value) => nextState.copyWith(
              contraindications: [...nextState.contraindications, value],
            ),
          ),
          onAdd: (value) => onChanged(
            state.copyWith(
              contraindications: [...state.contraindications, value],
            ),
          ),
          onRemove: (value) => onChanged(
            state.copyWith(
              contraindications: _removeFirstString(
                state.contraindications,
                value,
              ),
            ),
          ),
        ),
        SectionTitle(
          'Врачи и клиники',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Добавить врача или клинику',
            onPressed: () => _editCareProvider(context, state, onChanged),
            icon: const Icon(Icons.add),
          ),
        ),
        if (state.careProviders.isEmpty)
          const InfoTile(
            icon: Icons.local_hospital_outlined,
            title: 'Врачи и клиники не добавлены',
            subtitle:
                'Сохраните лечащих врачей, клиники, телефоны и адреса для связи с медкартой.',
          ),
        ...state.careProviders.map(
          (provider) => InfoTile(
            icon: Icons.local_hospital_outlined,
            title:
                '${provider.name}${provider.specialty.isEmpty ? '' : ' · ${provider.specialty}'}',
            subtitle:
                '${provider.role}${provider.clinic.isEmpty ? '' : ' · ${provider.clinic}'}\n${[provider.phone, provider.address, provider.notes].where((value) => value.isNotEmpty).join('\n')}',
            onTap: () => _editCareProvider(context, state, onChanged, provider),
            onLongPress: () => _confirmDelete(
              context,
              title: provider.name,
              onDelete: () => onChanged(
                state.copyWith(
                  careProviders: state.careProviders
                      .where((item) => item.id != provider.id)
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        SectionTitle(
          'События медкарты',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Добавить событие',
            onPressed: () =>
                _editMedicalEvent(context, state, onChanged, null, false),
            icon: const Icon(Icons.add),
          ),
        ),
        if (state.medicalEvents.isEmpty)
          const InfoTile(
            icon: Icons.event_note_outlined,
            title: 'События не добавлены',
            subtitle:
                'Сюда можно занести операции, перенесенные болезни, госпитализации, консультации и реабилитацию.',
          ),
        ...state.medicalEvents.map(
          (event) => InfoTile(
            icon: Icons.event_note_outlined,
            title:
                '${event.title}${event.bodyArea.isEmpty ? '' : ' · ${event.bodyArea}'}',
            subtitle:
                '${displayDateKey(event.date)} · ${event.kind} · ${event.severity}\n${[event.provider, event.notes].where((value) => value.isNotEmpty).join('\n')}',
            onTap: () =>
                _editMedicalEvent(context, state, onChanged, event, false),
            onLongPress: () => _confirmDelete(
              context,
              title: event.title,
              onDelete: () => onChanged(
                state.copyWith(
                  medicalEvents: state.medicalEvents
                      .where((item) => item.id != event.id)
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        SectionTitle(
          'Травмы в течение жизни',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Добавить травму',
            onPressed: () =>
                _editMedicalEvent(context, state, onChanged, null, true),
            icon: const Icon(Icons.add),
          ),
        ),
        if (state.injuries.isEmpty)
          const InfoTile(
            icon: Icons.personal_injury_outlined,
            title: 'Травмы не добавлены',
            subtitle: 'Добавьте перенесённые травмы, операции или ограничения.',
          ),
        ...state.injuries.map(
          (injury) => InfoTile(
            icon: Icons.personal_injury_outlined,
            title: '${injury.title} · ${injury.severity}',
            subtitle:
                '${displayDateKey(injury.date)} · ${injury.kind}\n${injury.notes}',
            onTap: () =>
                _editMedicalEvent(context, state, onChanged, injury, true),
            onLongPress: () => _confirmDelete(
              context,
              title: injury.title,
              onDelete: () => onChanged(
                state.copyWith(
                  injuries: state.injuries
                      .where((item) => item.id != injury.id)
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key, required this.state, required this.onChanged});

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'labs'),
      subtitle: 'Ручной ввод, OCR-кандидаты и спокойная динамика показателей',
      trailing: FilledButton.icon(
        onPressed: () => _addLab(context, state, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Анализ'),
      ),
      children: [
        const MedicalDisclaimerBanner(),
        ...state.labResults.map(
          (item) => InfoTile(
            icon: item.outsideReference
                ? Icons.warning_amber_outlined
                : Icons.science_outlined,
            title: '${item.marker}: ${item.value} ${item.unit}',
            subtitle:
                'Референс ${item.reference} · ${displayDateKey(item.date)} · ${item.referenceStatus}\n'
                '${_labPlainLanguage(item)}${item.notes.isEmpty ? '' : '\n${item.notes}'}',
            onTap: () => _addLab(context, state, onChanged, item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.marker,
              onDelete: () => onChanged(
                state.copyWith(
                  labResults: state.labResults
                      .where((candidate) => candidate.id != item.id)
                      .toList(),
                ),
              ),
            ),
            trailing: item.outsideReference
                ? const Pill(label: 'обсудить', icon: Icons.priority_high)
                : const Pill(label: 'в норме', icon: Icons.check),
          ),
        ),
        SectionTitle('OCR и ручное подтверждение'),
        ...state.confirmationQueue
            .where((item) => item.requiresMedicalReview)
            .map((item) => _confirmationTile(item, state, onChanged)),
      ],
    );
  }
}

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'medicines'),
      subtitle: 'Расписание, отметки приёма и напоминания',
      trailing: Wrap(
        spacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _addMedicationIntake(context, state, onChanged),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Приём'),
          ),
          FilledButton.icon(
            onPressed: () => _addMedication(context, state, onChanged),
            icon: const Icon(Icons.add),
            label: const Text('Лекарство'),
          ),
        ],
      ),
      children: [
        const MedicalDisclaimerBanner(),
        if (state.medicationIntakes.isNotEmpty) ...[
          SectionTitle('Журнал приёма'),
          ...state.medicationIntakes
              .take(8)
              .map(
                (item) => InfoTile(
                  icon: Icons.fact_check_outlined,
                  title: '${item.medicationName} · ${item.dose}',
                  subtitle:
                      '${item.date} ${item.time} · ${item.status}\n${item.notes}',
                  onTap: () =>
                      _addMedicationIntake(context, state, onChanged, item),
                  onLongPress: () => _confirmDelete(
                    context,
                    title: item.medicationName,
                    onDelete: () => onChanged(
                      _deleteMedicationIntakeFromState(state, item),
                    ),
                  ),
                ),
              ),
        ],
        SectionTitle('Препараты'),
        ...state.medications.map(
          (item) => InfoTile(
            icon: Icons.medication_outlined,
            title: '${item.name} · ${item.dose}',
            subtitle: _medicationSubtitle(item),
            onTap: () => _addMedication(context, state, onChanged, item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.name,
              onDelete: () {
                final medications = state.medications
                    .where((candidate) => candidate.id != item.id)
                    .toList();
                onChanged(
                  state.copyWith(
                    medications: medications,
                    today: state.today.copyWith(
                      medicationTaken: _allMedicationTakenOnDate(
                        medications,
                        state.medicationIntakes,
                        state.today.date,
                      ),
                    ),
                  ),
                );
              },
            ),
            trailing: Wrap(
              spacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LocalizedIconButton(
                  tooltip: 'Принято',
                  onPressed: () => onChanged(
                    _setMedicationIntakeStatusToday(state, item, 'принято'),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                ),
                LocalizedIconButton(
                  tooltip: 'Перенесено',
                  onPressed: () => onChanged(
                    _setMedicationIntakeStatusToday(state, item, 'перенесено'),
                  ),
                  icon: const Icon(Icons.schedule_send_outlined),
                ),
                LocalizedIconButton(
                  tooltip: 'Пропущено',
                  onPressed: () => onChanged(
                    _setMedicationIntakeStatusToday(state, item, 'пропущено'),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Checkbox(
                  value: state.medicationTakenOnDate(item, state.today.date),
                  onChanged: (value) {
                    onChanged(_toggleMedicationIntakeToday(state, item, value));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SymptomsScreen extends StatelessWidget {
  const SymptomsScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final alarming =
        state.symptomEntries.any((item) => item.needsAttention) ||
        state.today.symptoms.any(_isAlarmingSymptom) ||
        state.symptomNotes.any(_isAlarmingSymptom);
    final symptomDays =
        [
          state.today,
          ...state.dailyHistory.where((item) => item.date != state.today.date),
        ].where((item) => item.symptoms.isNotEmpty).toList()..sort(
          (a, b) => b.date.compareTo(a.date),
        );
    return PageBand(
      title: AppText.get(state.localeCode, 'symptoms'),
      subtitle: 'Дневник самочувствия без диагнозов и назначений',
      trailing: FilledButton.icon(
        onPressed: () => _editSymptomEntry(context, state, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Симптом'),
      ),
      children: [
        const MedicalDisclaimerBanner(),
        if (alarming)
          InfoTile(
            icon: Icons.emergency_outlined,
            title: 'Есть тревожные формулировки',
            subtitle:
                'При острой боли, нарушении речи, сильной одышке, потере сознания или резком ухудшении обратитесь за экстренной помощью.',
          ),
        if (state.symptomEntries.isNotEmpty)
          SectionTitle('Структурированный журнал'),
        ...([...state.symptomEntries]..sort((a, b) {
              final dateOrder = b.date.compareTo(a.date);
              return dateOrder == 0 ? b.time.compareTo(a.time) : dateOrder;
            }))
            .map(
              (item) => InfoTile(
                icon: item.needsAttention
                    ? Icons.warning_amber_outlined
                    : Icons.monitor_heart_outlined,
                title: '${item.symptom} · ${item.intensity}/10',
                subtitle: _symptomEntrySubtitle(state, item),
                onTap: () => _editSymptomEntry(context, state, onChanged, item),
                onLongPress: () => _confirmDelete(
                  context,
                  title: item.symptom,
                  onDelete: () => onChanged(
                    state.copyWith(
                      symptomEntries: state.symptomEntries
                          .where((candidate) => candidate.id != item.id)
                          .toList(),
                    ),
                  ),
                ),
                trailing: item.needsAttention
                    ? const Pill(
                        label: 'обсудить',
                        icon: Icons.medical_information_outlined,
                      )
                    : null,
              ),
            ),
        if (_repeatingSymptomWarning(state) case final warning?)
          InfoTile(
            icon: Icons.date_range_outlined,
            title: 'Симптом повторяется',
            subtitle: warning,
          ),
        if (state.today.symptoms.isNotEmpty) SectionTitle('Старые записи'),
        ...state.today.symptoms.map(
          (item) => InfoTile(
            icon: Icons.today_outlined,
            title: item,
            subtitle: 'Отмечено сегодня',
            onLongPress: () => _confirmDelete(
              context,
              title: item,
              onDelete: () => onChanged(
                _deleteSymptomFromDate(state, state.today.date, item),
              ),
            ),
          ),
        ),
        if (symptomDays
            .where((item) => item.date != state.today.date)
            .isNotEmpty)
          SectionTitle('История по датам'),
        ...symptomDays
            .where((day) => day.date != state.today.date)
            .expand(
              (day) => day.symptoms.map(
                (item) => InfoTile(
                  icon: Icons.event_note_outlined,
                  title: item,
                  subtitle: day.date,
                  onLongPress: () => _confirmDelete(
                    context,
                    title: item,
                    onDelete: () => onChanged(
                      _deleteSymptomFromDate(state, day.date, item),
                    ),
                  ),
                ),
              ),
            ),
        if (state.symptomNotes.isNotEmpty) SectionTitle('Личные заметки'),
        ...state.symptomNotes.map(
          (item) => InfoTile(
            icon: Icons.notes_outlined,
            title: item,
            subtitle: 'Старая свободная запись',
            onLongPress: () => _confirmDelete(
              context,
              title: item,
              onDelete: () => onChanged(
                state.copyWith(
                  symptomNotes: _removeFirstString(state.symptomNotes, item),
                ),
              ),
            ),
          ),
        ),
        if (symptomDays.isEmpty &&
            state.symptomNotes.isEmpty &&
            state.symptomEntries.isEmpty)
          const InfoTile(
            icon: Icons.sentiment_satisfied_alt_outlined,
            title: 'Записей пока нет',
            subtitle: 'Добавьте симптом за сегодня или любой другой день.',
          ),
      ],
    );
  }
}
