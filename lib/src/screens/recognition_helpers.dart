part of '../screens.dart';

Widget _confirmationTile(
  RecognitionCandidate item,
  HealthAppState state,
  HealthStateChanged onChanged,
) {
  final createdAt = item.createdAt.isEmpty ? todayKey() : item.createdAt;
  final fileInfo = item.filePath.isEmpty
      ? ''
      : '\nФайл: ${item.filePath}\nИсточник: ${item.kind} · дата импорта: $createdAt';
  final metadataInfo = _recognitionMetadataSummary(item);
  final confidenceHint = item.requiresMedicalReview
      ? item.confidence < 0.5
            ? '\nНизкая уверенность OCR: сравните все значения с исходным документом.'
            : '\nРаспознанные значения обязательно сравните с исходным документом.'
      : item.confidence < 0.5
      ? '\nНизкая уверенность: сделайте дополнительное фото или укажите название и размер порции вручную.'
      : '\nЭто оценка по изображению/этикетке; проверьте данные вручную.';
  return Builder(
    builder: (context) => InfoTile(
      icon: item.requiresMedicalReview
          ? Icons.science_outlined
          : Icons.restaurant_outlined,
      title: item.title,
      subtitle:
          '${item.source} · уверенность ${(item.confidence * 100).round()}%$fileInfo$metadataInfo$confidenceHint\n${item.requiresMedicalReview ? medicalDisclaimer : 'Применяется только после ручного подтверждения.'}',
      onLongPress: () => _confirmDelete(
        context,
        title: item.title,
        onDelete: () => onChanged(_removeRecognitionCandidate(state, item)),
      ),
      trailing: Wrap(
        spacing: 6,
        children: [
          LocalizedIconButton.filledTonal(
            tooltip: 'Отклонить',
            onPressed: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () =>
                  onChanged(_removeRecognitionCandidate(state, item)),
            ),
            icon: const Icon(Icons.close),
          ),
          LocalizedIconButton.filledTonal(
            tooltip: 'Исправить',
            onPressed: () =>
                _editRecognitionCandidate(context, item, state, onChanged),
            icon: const Icon(Icons.edit_outlined),
          ),
          LocalizedIconButton.filled(
            tooltip: 'Подтвердить',
            onPressed: () async {
              final queue = state.confirmationQueue
                  .where((candidate) => candidate.id != item.id)
                  .toList();
              if (item.requiresMedicalReview) {
                final sourceMarker = 'ocr-source:${item.filePath}';
                final existingDocument = state.documents
                    .where(
                      (document) =>
                          document.searchText.contains(sourceMarker) ||
                          document.filePath == item.filePath,
                    )
                    .firstOrNull;
                final documentId = existingDocument?.id ?? newId();
                var protectedPath = existingDocument?.filePath ?? item.filePath;
                if (item.filePath.isNotEmpty && existingDocument == null) {
                  try {
                    protectedPath = await DocumentVaultService.instance
                        .importFile(item.filePath, documentId);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Не удалось защитить исходный анализ: $error',
                        ),
                      ),
                    );
                    return;
                  }
                }
                final marker = _metadataValue(
                  item,
                  'marker',
                  fallback: item.title,
                );
                final value = _metadataValue(item, 'value');
                final unit = _metadataValue(item, 'unit');
                final reference = _metadataValue(item, 'reference');
                final missingFields = [
                  if (value.isEmpty) 'значение',
                  if (unit.isEmpty) 'единицы',
                  if (reference.isEmpty) 'референс',
                ];
                final missingNote = missingFields.isEmpty
                    ? ''
                    : ' Не извлечено: ${missingFields.join(', ')}.';
                final referenceProbe = LabResult(
                  id: 'probe',
                  marker: marker,
                  value: value,
                  unit: unit,
                  reference: reference,
                  date: createdAt,
                  needsAttention: false,
                  notes: '',
                );
                final outsideReference =
                    referenceProbe.referenceStatus == 'ниже референса' ||
                    referenceProbe.referenceStatus == 'выше референса';
                onChanged(
                  state.copyWith(
                    confirmationQueue: queue,
                    labResults: [
                      LabResult(
                        id: newId(),
                        marker: marker,
                        value: value,
                        unit: unit,
                        reference: reference,
                        date: createdAt,
                        needsAttention:
                            missingFields.isNotEmpty || outsideReference,
                        notes:
                            'Импортировано из OCR после ручного подтверждения.$missingNote${item.filePath.isEmpty ? '' : ' Исходный файл сохранён.'}',
                      ),
                      ...state.labResults,
                    ],
                    documents: [
                      if (item.filePath.isNotEmpty && existingDocument == null)
                        HealthDocument(
                          id: documentId,
                          title: item.title,
                          kind: item.kind == 'camera'
                              ? 'снимок OCR'
                              : 'файл OCR',
                          date: createdAt,
                          locked: true,
                          notes:
                              'Исходный материал для распознавания и ручной проверки.',
                          filePath: protectedPath,
                          fileName: item.filePath.split(RegExp(r'[\\/]')).last,
                          searchText: sourceMarker,
                        ),
                      ...state.documents,
                    ],
                  ),
                );
                if (protectedPath != item.filePath &&
                    item.filePath.isNotEmpty) {
                  unawaited(_deleteImportedRecognitionSource(item.filePath));
                }
                return;
              }
              final metrics = state.metricsFor(createdAt);
              final calories = _metadataInt(item, 'calories', 0);
              final protein = _metadataInt(item, 'protein', 0);
              final carbs = _metadataInt(item, 'carbs', 0);
              final fat = _metadataInt(item, 'fat', 0);
              final portionGrams = _metadataInt(item, 'portionGrams', 0);
              final fiber = _metadataInt(item, 'fiber', 0);
              final sugar = _metadataInt(item, 'sugar', 0);
              final salt = _metadataDouble(item, 'salt', 0);
              final basisGrams = _metadataInt(item, 'nutritionBasisGrams', 0);
              final factor = basisGrams > 0 && portionGrams > 0
                  ? portionGrams / basisGrams
                  : 1.0;
              int scaledInt(int value) => (value * factor).round();
              final scaledCalories = scaledInt(calories);
              onChanged(
                state
                    .updateMetricsFor(
                      createdAt,
                      metrics.copyWith(
                        calories: metrics.calories + scaledCalories,
                      ),
                    )
                    .copyWith(
                      confirmationQueue: queue,
                      meals: [
                        MealEntry(
                          id: newId(),
                          title: item.title,
                          kind: _metadataValue(
                            item,
                            'mealKind',
                            fallback: 'фото еды',
                          ),
                          calories: scaledCalories,
                          protein: scaledInt(protein),
                          carbs: scaledInt(carbs),
                          fat: scaledInt(fat),
                          confirmed: true,
                          notes:
                              'Подтверждено пользователем после распознавания.'
                              '${factor == 1 ? '' : ' Значения пересчитаны с $basisGrams г на порцию $portionGrams г.'}',
                          date: createdAt,
                          imagePath: item.filePath,
                          source: item.kind,
                          portionGrams: portionGrams,
                          fiber: scaledInt(fiber),
                          sugar: scaledInt(sugar),
                          salt: salt * factor,
                        ),
                        ...state.meals,
                      ],
                    ),
              );
            },
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    ),
  );
}

Future<void> _deleteImportedRecognitionSource(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // The encrypted copy is already stored; stale media can be cleaned later.
  }
}

Future<void> _editRecognitionCandidate(
  BuildContext context,
  RecognitionCandidate item,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final title = TextEditingController(text: item.title);
  final metadata = Map<String, String>.from(item.metadata);
  final fields = item.requiresMedicalReview
      ? <String, String>{
          'marker': 'Показатель',
          'value': 'Значение',
          'unit': 'Единица',
          'reference': 'Референс',
        }
      : <String, String>{
          'mealKind': 'Тип приёма пищи',
          'calories': 'Ккал',
          'protein': 'Белок, г',
          'carbs': 'Углеводы, г',
          'fat': 'Жиры, г',
          'sugar': 'Сахар, г',
          'fiber': 'Клетчатка, г',
          'salt': 'Соль, г',
          'portionGrams': 'Оценка порции, г',
          'nutritionBasisGrams': 'Пищевая ценность указана на, г',
        };
  final controllers = {
    for (final entry in fields.entries)
      entry.key: TextEditingController(text: metadata[entry.key] ?? ''),
  };
  final visualAlternatives = _visualRecognitionAlternatives(metadata);
  var selectedVisualLabel = metadata['visualLabel'] ?? '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Проверка распознавания'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (visualAlternatives.isNotEmpty) ...[
                  Text(
                    'Варианты визуальной модели',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final alternative in visualAlternatives)
                        ChoiceChip(
                          label: Text(
                            '${alternative['titleRu']} · ${(((alternative['confidence'] as num?) ?? 0) * 100).round()}%',
                          ),
                          selected: selectedVisualLabel == alternative['label'],
                          onSelected: (_) {
                            final label = '${alternative['label'] ?? ''}';
                            if (label.isEmpty) return;
                            setDialogState(() {
                              selectedVisualLabel = label;
                              metadata['visualLabel'] = label;
                              metadata['visualTitle'] =
                                  '${alternative['titleRu'] ?? label}';
                              metadata['visualConfidence'] =
                                  '${alternative['confidence'] ?? 0}';
                              metadata['nutritionEstimate'] = 'true';
                              for (final key in const [
                                'servingGrams',
                                'calories',
                                'protein',
                                'fat',
                                'carbs',
                              ]) {
                                final controllerKey = key == 'servingGrams'
                                    ? 'portionGrams'
                                    : key;
                                final value = '${alternative[key] ?? ''}';
                                if (value.isNotEmpty) {
                                  metadata[controllerKey] = value;
                                  controllers[controllerKey]?.text = value;
                                }
                              }
                              metadata['nutritionBasisGrams'] = '100';
                              controllers['nutritionBasisGrams']?.text = '100';
                              title.text =
                                  '${alternative['titleRu'] ?? label} · визуальная оценка';
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Вес порции и пищевая ценность являются ориентировочной оценкой класса блюда. Проверьте их перед подтверждением.',
                  ),
                  const SizedBox(height: 12),
                ],
                LocalizedTextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Название результата',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in fields.entries)
                  LocalizedTextField(
                    controller: controllers[entry.key],
                    decoration: InputDecoration(
                      labelText: entry.value,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                if ((metadata['rawText'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    metadata['rawText']!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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
              for (final entry in controllers.entries) {
                final value = entry.value.text.trim();
                if (value.isEmpty) {
                  metadata.remove(entry.key);
                } else {
                  metadata[entry.key] = value;
                }
              }
              final queue = state.confirmationQueue
                  .where((candidate) => candidate.id != item.id)
                  .toList();
              final updated = RecognitionCandidate(
                id: newId(),
                source: item.source,
                title: title.text.trim().isEmpty
                    ? item.title
                    : title.text.trim(),
                confidence: 1,
                requiresMedicalReview: item.requiresMedicalReview,
                filePath: item.filePath,
                kind: item.kind,
                createdAt: item.createdAt,
                metadata: metadata,
              );
              onChanged(state.copyWith(confirmationQueue: [updated, ...queue]));
              Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
  for (final controller in controllers.values) {
    controller.dispose();
  }
  title.dispose();
}

List<Map<String, dynamic>> _visualRecognitionAlternatives(
  Map<String, String> metadata,
) {
  final raw = metadata['visualAlternatives'];
  if (raw == null || raw.isEmpty) return const [];
  try {
    return (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

HealthAppState _removeRecognitionCandidate(
  HealthAppState state,
  RecognitionCandidate item,
) {
  return state.copyWith(
    confirmationQueue: state.confirmationQueue
        .where((candidate) => candidate.id != item.id)
        .toList(),
  );
}

String _recognitionMetadataSummary(RecognitionCandidate item) {
  if (item.metadata.isEmpty) {
    return '';
  }
  if (item.requiresMedicalReview) {
    final marker = _metadataValue(item, 'marker');
    final value = _metadataValue(item, 'value');
    final unit = _metadataValue(item, 'unit');
    final reference = _metadataValue(item, 'reference');
    final parts = [
      if (marker.isNotEmpty) marker,
      if (value.isNotEmpty) '$value $unit'.trim(),
      if (reference.isNotEmpty) 'референс $reference',
    ];
    return parts.isEmpty ? '' : '\nРаспознано: ${parts.join(' · ')}';
  }
  final calories = _metadataValue(item, 'calories');
  final protein = _metadataValue(item, 'protein');
  final carbs = _metadataValue(item, 'carbs');
  final fat = _metadataValue(item, 'fat');
  final portion = _metadataValue(item, 'portionGrams');
  final sugar = _metadataValue(item, 'sugar');
  final fiber = _metadataValue(item, 'fiber');
  final salt = _metadataValue(item, 'salt');
  final basis = _metadataValue(item, 'nutritionBasisGrams');
  final visualTitle = _metadataValue(item, 'visualTitle');
  final visualConfidence = _metadataDouble(item, 'visualConfidence', 0);
  final parts = [
    if (visualTitle.isNotEmpty)
      '$visualTitle · модель ${(visualConfidence * 100).round()}%',
    if (calories.isNotEmpty) '$calories ккал',
    if (protein.isNotEmpty) 'Б $protein',
    if (fat.isNotEmpty) 'Ж $fat',
    if (carbs.isNotEmpty) 'У $carbs',
    if (portion.isNotEmpty) 'порция ~$portion г',
    if (sugar.isNotEmpty) 'сахар $sugar г',
    if (fiber.isNotEmpty) 'клетчатка $fiber г',
    if (salt.isNotEmpty) 'соль $salt г',
    if (basis.isNotEmpty) 'значения на $basis г',
  ];
  final estimateNote = item.metadata['nutritionEstimate'] == 'true'
      ? '\nПищевая ценность и стандартная порция являются оценкой; проверьте их вручную.'
      : '';
  final status = _metadataValue(item, 'visualStatus');
  return parts.isEmpty && status.isEmpty
      ? ''
      : '\nРаспознано: ${parts.join(' · ')}'
            '${status.isEmpty ? '' : '\n$status'}$estimateNote';
}

String _metadataValue(
  RecognitionCandidate item,
  String key, {
  String fallback = '',
}) {
  final value = item.metadata[key]?.trim();
  return value == null || value.isEmpty ? fallback : value;
}

int _metadataInt(RecognitionCandidate item, String key, int fallback) {
  final value = item.metadata[key]?.replaceAll(',', '.').trim();
  return int.tryParse(value ?? '') ??
      double.tryParse(value ?? '')?.round() ??
      fallback;
}

double _metadataDouble(RecognitionCandidate item, String key, double fallback) {
  final value = item.metadata[key]?.replaceAll(',', '.').trim();
  return double.tryParse(value ?? '') ?? fallback;
}
