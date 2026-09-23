part of '../screens.dart';

bool _isPrescriptionCandidate(RecognitionCandidate item) =>
    item.metadata['candidateType'] == 'prescription';

Widget _prescriptionCandidateTile(
  BuildContext context,
  RecognitionCandidate candidate,
  HealthAppState state,
  HealthStateChanged onChanged,
) {
  final metadata = candidate.metadata;
  final name = metadata['name']?.trim();
  final dose = metadata['dose']?.trim();
  final schedule = metadata['schedule']?.trim();
  final summary = [
    if (dose?.isNotEmpty == true) dose!,
    if (schedule?.isNotEmpty == true) schedule!,
  ].join(' · ');
  return InfoTile(
    icon: Icons.assignment_turned_in_outlined,
    title: name?.isNotEmpty == true ? name! : candidate.title,
    subtitle:
        '${summary.isEmpty ? 'Поля назначения требуют проверки' : summary}\n'
        '${candidate.source} · уверенность ${(candidate.confidence * 100).round()}%\n'
        'Сверьте название, дозу и расписание с оригиналом.',
    onTap: () =>
        _reviewDeferredPrescription(context, candidate, state, onChanged),
    onLongPress: () => _confirmDelete(
      context,
      title: candidate.title,
      onDelete: () => onChanged(_removeRecognitionCandidate(state, candidate)),
    ),
    trailing: Wrap(
      spacing: 4,
      children: [
        LocalizedIconButton(
          tooltip: 'Отклонить назначение',
          onPressed: () => _confirmDelete(
            context,
            title: candidate.title,
            onDelete: () =>
                onChanged(_removeRecognitionCandidate(state, candidate)),
          ),
          icon: const Icon(Icons.close),
        ),
        LocalizedIconButton.filledTonal(
          tooltip: 'Проверить назначение',
          onPressed: () =>
              _reviewDeferredPrescription(context, candidate, state, onChanged),
          icon: const Icon(Icons.fact_check_outlined),
        ),
      ],
    ),
  );
}

Future<void> _reviewDeferredPrescription(
  BuildContext context,
  RecognitionCandidate candidate,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final medication = await _reviewPrescriptionCandidate(
    context,
    candidate,
    state,
  );
  if (medication == null || !context.mounted) return;
  onChanged(
    state.copyWith(
      medications: [
        medication,
        ...state.medications.where(
          (item) => item.name.toLowerCase() != medication.name.toLowerCase(),
        ),
      ],
      confirmationQueue: state.confirmationQueue
          .where((item) => item.id != candidate.id)
          .toList(),
    ),
  );
}

Future<void> _importPrescription(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, {
  required bool camera,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        camera
            ? 'Открываем камеру и распознаём назначение...'
            : 'Открываем рецепт и распознаём назначение...',
      ),
      duration: const Duration(seconds: 2),
    ),
  );
  try {
    final candidates = await MediaImportService().importPrescriptionBatch(
      camera: camera,
    );
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Препараты не распознаны. Проверьте качество снимка или добавьте лекарство вручную.',
          ),
        ),
      );
      return;
    }
    var workingState = state;
    final deferred = <RecognitionCandidate>[];
    var accepted = 0;
    for (final candidate in candidates) {
      if (!context.mounted) return;
      final medication = await _reviewPrescriptionCandidate(
        context,
        candidate,
        workingState,
      );
      if (medication == null) {
        deferred.add(candidate);
        continue;
      }
      accepted++;
      workingState = workingState.copyWith(
        medications: [
          medication,
          ...workingState.medications.where(
            (item) => item.name.toLowerCase() != medication.name.toLowerCase(),
          ),
        ],
      );
    }
    workingState = workingState.copyWith(
      confirmationQueue: [...deferred, ...workingState.confirmationQueue],
    );
    onChanged(workingState);
    if (!context.mounted) return;
    final deferredLabel = deferred.isEmpty
        ? ''
        : '; отложено на проверку: ${deferred.length}';
    messenger.showSnackBar(
      SnackBar(
        content: Text('Подтверждено препаратов: $accepted$deferredLabel'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Не удалось распознать рецепт: $error')),
    );
  }
}

Future<Medication?> _reviewPrescriptionCandidate(
  BuildContext context,
  RecognitionCandidate candidate,
  HealthAppState state,
) async {
  final metadata = candidate.metadata;
  final name = TextEditingController(text: metadata['name'] ?? '');
  final dose = TextEditingController(text: metadata['dose'] ?? '');
  final form = TextEditingController(text: metadata['form'] ?? '');
  final schedule = TextEditingController(text: metadata['schedule'] ?? '');
  final foodRule = TextEditingController(text: metadata['foodRule'] ?? '');
  final duration = metadata['courseDuration'] ?? '';
  final initialStart = metadata['courseStart']?.isNotEmpty == true
      ? metadata['courseStart']!
      : duration.isEmpty
      ? ''
      : dateInputText(todayKey());
  final courseStart = TextEditingController(text: initialStart);
  final courseEnd = TextEditingController(
    text: metadata['courseEnd']?.isNotEmpty == true
        ? metadata['courseEnd']!
        : _courseEndForDuration(duration),
  );
  final doctor = TextEditingController();
  final condition = TextEditingController();
  final notes = TextEditingController(
    text:
        'Распознано из рецепта. Уверенность ${(candidate.confidence * 100).round()}%. '
        'Сверено пользователем с оригиналом.',
  );
  String? validationError;

  try {
    return await showDialog<Medication>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Проверка назначения'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MedicalDisclaimerBanner(),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: candidate.confidence),
                  const SizedBox(height: 6),
                  Text(
                    'Уверенность OCR ${(candidate.confidence * 100).round()}%. '
                    'Сверьте каждое поле с рецептом; приложение не проверяет назначение и не меняет дозу.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  LocalizedTextField(
                    controller: name,
                    autofocus: name.text.isEmpty,
                    decoration: const InputDecoration(
                      labelText: 'Название препарата',
                    ),
                  ),
                  LocalizedTextField(
                    controller: dose,
                    decoration: const InputDecoration(
                      labelText: 'Доза из назначения',
                    ),
                  ),
                  LocalizedTextField(
                    controller: form,
                    decoration: const InputDecoration(labelText: 'Форма'),
                  ),
                  LocalizedTextField(
                    controller: schedule,
                    decoration: const InputDecoration(
                      labelText: 'Расписание и кратность',
                      helperText:
                          'Для уведомлений укажите время в формате 08:00, 20:00',
                    ),
                  ),
                  LocalizedTextField(
                    controller: foodRule,
                    decoration: const InputDecoration(
                      labelText: 'Связь с едой',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _prescriptionDateField(
                          context,
                          controller: courseStart,
                          label: 'Начало курса',
                          onChanged: () => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _prescriptionDateField(
                          context,
                          controller: courseEnd,
                          label: 'Конец курса',
                          onChanged: () => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  LocalizedTextField(
                    controller: doctor,
                    decoration: const InputDecoration(
                      labelText: 'Назначивший врач',
                    ),
                  ),
                  LocalizedTextField(
                    controller: condition,
                    decoration: const InputDecoration(
                      labelText: 'Связанное состояние',
                    ),
                  ),
                  LocalizedTextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Заметки'),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Исходный распознанный текст'),
                    children: [SelectableText(metadata['rawText'] ?? '')],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отложить'),
            ),
            FilledButton.icon(
              onPressed: () {
                final normalizedStart = dateStorageText(
                  courseStart.text,
                  fallback: '',
                );
                final normalizedEnd = dateStorageText(
                  courseEnd.text,
                  fallback: '',
                );
                if (name.text.trim().isEmpty ||
                    dose.text.trim().isEmpty ||
                    schedule.text.trim().isEmpty) {
                  setDialogState(
                    () => validationError =
                        'Проверьте название, дозу и расписание.',
                  );
                  return;
                }
                if (courseStart.text.isNotEmpty &&
                        parseDateKey(normalizedStart) == null ||
                    courseEnd.text.isNotEmpty &&
                        parseDateKey(normalizedEnd) == null) {
                  setDialogState(
                    () => validationError = 'Проверьте даты курса.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  Medication(
                    id: newId(),
                    name: name.text.trim(),
                    dose: dose.text.trim(),
                    schedule: schedule.text.trim(),
                    takenToday: false,
                    notes: notes.text.trim(),
                    category: _prescriptionCategory(name.text, form.text),
                    loggedDate: state.today.date,
                    form: form.text.trim(),
                    courseStart: normalizedStart,
                    courseEnd: normalizedEnd,
                    foodRule: foodRule.text.trim(),
                    prescribingDoctor: doctor.text.trim(),
                    linkedCondition: condition.text.trim(),
                    remainingUnits: 0,
                    lowStockThreshold: 0,
                    sideEffects: '',
                    purchaseReminder: false,
                  ),
                );
              },
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Подтвердить'),
            ),
          ],
        ),
      ),
    );
  } finally {
    name.dispose();
    dose.dispose();
    form.dispose();
    schedule.dispose();
    foodRule.dispose();
    courseStart.dispose();
    courseEnd.dispose();
    doctor.dispose();
    condition.dispose();
    notes.dispose();
  }
}

Widget _prescriptionDateField(
  BuildContext context, {
  required TextEditingController controller,
  required String label,
  required VoidCallback onChanged,
}) {
  return LocalizedTextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'ДД.ММ.ГГГГ',
      suffixIcon: LocalizedIconButton(
        tooltip: 'Выбрать дату',
        onPressed: () async {
          final picked = await _pickDateValue(context, controller.text);
          if (picked == null) return;
          controller.text = dateInputText(todayKey(picked));
          onChanged();
        },
        icon: const Icon(Icons.calendar_month_outlined),
      ),
    ),
    inputFormatters: dateInputFormatters,
    keyboardType: TextInputType.number,
  );
}

String _courseEndForDuration(String duration) {
  final amount = int.tryParse(
    RegExp(r'\d+').firstMatch(duration)?.group(0) ?? '',
  );
  if (amount == null || amount <= 0) return '';
  var days = amount;
  final lower = duration.toLowerCase();
  if (lower.contains('недел')) days *= 7;
  if (lower.contains('месяц')) days *= 30;
  return dateInputText(todayKey(DateTime.now().add(Duration(days: days - 1))));
}

String _prescriptionCategory(String name, String form) {
  final lower = '$name $form'.toLowerCase();
  if (lower.contains('витамин') || lower.contains('vitamin')) return 'витамин';
  if (lower.contains('инсулин')) return 'инсулин';
  if (lower.contains('маз') || lower.contains('крем')) return 'наружное';
  return 'лекарство';
}
