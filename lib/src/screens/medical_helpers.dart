part of '../screens.dart';

Future<void> _editMedicalEvent(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  MedicalEvent? event,
  bool useInjuryList = false,
]) async {
  final title = TextEditingController(text: event?.title ?? '');
  final date = TextEditingController(
    text: dateInputText(event?.date ?? state.today.date),
  );
  final notes = TextEditingController(text: event?.notes ?? '');
  final provider = TextEditingController(text: event?.provider ?? '');
  final bodyArea = TextEditingController(text: event?.bodyArea ?? '');
  var kind = event?.kind.isNotEmpty == true ? event!.kind : 'травма';
  var severity = event?.severity.isNotEmpty == true
      ? event!.severity
      : 'средняя';
  var linkedDocumentId = event?.linkedDocumentId ?? '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final documentItems = [
          const DropdownMenuItem(value: '', child: Text('без документа')),
          ...state.documents.map(
            (item) => DropdownMenuItem(value: item.id, child: Text(item.title)),
          ),
        ];
        return AlertDialog(
          title: Text(
            event == null
                ? (useInjuryList ? 'Добавить травму' : 'Добавить событие')
                : 'Редактировать событие',
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: операция, травма плеча, COVID-19',
                    ),
                  ),
                  LocalizedTextField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: 'Дата или примерная дата',
                      hintText: 'ДД.ММ.ГГГГ',
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать дату',
                        onPressed: () async {
                          final picked = await _pickDateValue(
                            context,
                            date.text,
                          );
                          if (picked != null) {
                            setDialogState(
                              () => date.text = dateInputText(todayKey(picked)),
                            );
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                    inputFormatters: dateInputFormatters,
                    keyboardType: TextInputType.number,
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const [
                      DropdownMenuItem(value: 'травма', child: Text('травма')),
                      DropdownMenuItem(
                        value: 'операция',
                        child: Text('операция'),
                      ),
                      DropdownMenuItem(
                        value: 'перенесённая болезнь',
                        child: Text('перенесённая болезнь'),
                      ),
                      DropdownMenuItem(
                        value: 'реабилитация',
                        child: Text('реабилитация'),
                      ),
                      DropdownMenuItem(
                        value: 'госпитализация',
                        child: Text('госпитализация'),
                      ),
                      DropdownMenuItem(
                        value: 'консультация',
                        child: Text('консультация'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => kind = value);
                      }
                    },
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: const InputDecoration(labelText: 'Тяжесть'),
                    items: const [
                      DropdownMenuItem(value: 'лёгкая', child: Text('лёгкая')),
                      DropdownMenuItem(
                        value: 'средняя',
                        child: Text('средняя'),
                      ),
                      DropdownMenuItem(
                        value: 'тяжёлая',
                        child: Text('тяжёлая'),
                      ),
                      DropdownMenuItem(
                        value: 'хронические последствия',
                        child: Text('хронические последствия'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => severity = value);
                      }
                    },
                  ),
                  LocalizedTextField(
                    controller: bodyArea,
                    decoration: const InputDecoration(
                      labelText: 'Область тела или система',
                      hintText: 'Например: колено, дыхательная система',
                    ),
                  ),
                  LocalizedTextField(
                    controller: provider,
                    decoration: InputDecoration(
                      labelText: 'Врач или клиника',
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: 'Выбрать из медкарты',
                        icon: const Icon(Icons.badge_outlined),
                        onSelected: (value) {
                          setDialogState(() => provider.text = value);
                        },
                        itemBuilder: (context) => [
                          for (final item in state.careProviders)
                            PopupMenuItem(
                              value: [
                                item.name,
                                item.clinic,
                              ].where((value) => value.isNotEmpty).join(' · '),
                              child: Text(item.name),
                            ),
                        ],
                      ),
                    ),
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: linkedDocumentId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Связанный документ',
                    ),
                    items: documentItems,
                    onChanged: (value) =>
                        setDialogState(() => linkedDocumentId = value ?? ''),
                  ),
                  LocalizedTextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Что важно учитывать',
                      hintText: 'Ограничения, реабилитация, врач, документы',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final titleValue = title.text.trim();
                if (titleValue.isEmpty) {
                  return;
                }
                final updated =
                    (event ??
                            MedicalEvent(
                              id: newId(),
                              title: titleValue,
                              date: dateStorageText(
                                date.text,
                                fallback: state.today.date,
                              ),
                              kind: kind,
                              severity: severity,
                              notes: notes.text.trim(),
                            ))
                        .copyWith(
                          title: titleValue,
                          date: dateStorageText(
                            date.text,
                            fallback: state.today.date,
                          ),
                          kind: kind,
                          severity: severity,
                          notes: notes.text.trim(),
                          provider: provider.text.trim(),
                          bodyArea: bodyArea.text.trim(),
                          linkedDocumentId: linkedDocumentId,
                        );
                if (useInjuryList) {
                  final injuries = event == null
                      ? [updated, ...state.injuries]
                      : state.injuries
                            .map((item) => item.id == event.id ? updated : item)
                            .toList();
                  onChanged(state.copyWith(injuries: injuries));
                } else {
                  final events = event == null
                      ? [updated, ...state.medicalEvents]
                      : state.medicalEvents
                            .map((item) => item.id == event.id ? updated : item)
                            .toList();
                  onChanged(state.copyWith(medicalEvents: events));
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _editCareProvider(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  CareProvider? provider,
]) async {
  final name = TextEditingController(text: provider?.name ?? '');
  final specialty = TextEditingController(text: provider?.specialty ?? '');
  final clinic = TextEditingController(text: provider?.clinic ?? '');
  final phone = TextEditingController(text: provider?.phone ?? '');
  final address = TextEditingController(text: provider?.address ?? '');
  final notes = TextEditingController(text: provider?.notes ?? '');
  var role = provider?.role.isNotEmpty == true ? provider!.role : 'врач';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          provider == null
              ? 'Добавить врача или клинику'
              : 'Редактировать контакт',
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocalizedDropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Тип контакта'),
                  items: const [
                    DropdownMenuItem(value: 'врач', child: Text('врач')),
                    DropdownMenuItem(value: 'клиника', child: Text('клиника')),
                    DropdownMenuItem(
                      value: 'лаборатория',
                      child: Text('лаборатория'),
                    ),
                    DropdownMenuItem(
                      value: 'страховая',
                      child: Text('страховая'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => role = value);
                    }
                  },
                ),
                LocalizedTextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Имя или название',
                    hintText: 'Например: Иванова А.А. или Городская клиника',
                  ),
                ),
                LocalizedTextField(
                  controller: specialty,
                  decoration: const InputDecoration(
                    labelText: 'Специализация',
                    hintText: 'Терапевт, кардиолог, травматолог',
                  ),
                ),
                LocalizedTextField(
                  controller: clinic,
                  decoration: const InputDecoration(labelText: 'Клиника'),
                ),
                LocalizedTextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                  keyboardType: TextInputType.phone,
                ),
                LocalizedTextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Адрес'),
                ),
                LocalizedTextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Заметка'),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final nameValue = name.text.trim();
              if (nameValue.isEmpty) {
                return;
              }
              final updated =
                  (provider ??
                          CareProvider(
                            id: newId(),
                            name: nameValue,
                            role: role,
                          ))
                      .copyWith(
                        name: nameValue,
                        role: role,
                        specialty: specialty.text.trim(),
                        clinic: clinic.text.trim(),
                        phone: phone.text.trim(),
                        address: address.text.trim(),
                        notes: notes.text.trim(),
                      );
              final providers = provider == null
                  ? [updated, ...state.careProviders]
                  : state.careProviders
                        .map((item) => item.id == provider.id ? updated : item)
                        .toList();
              onChanged(state.copyWith(careProviders: providers));
              Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}
