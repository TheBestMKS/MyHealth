part of '../screens.dart';

String _labPlainLanguage(LabResult item) {
  return switch (item.referenceStatus) {
    'ниже референса' =>
      'Значение ниже указанного лабораторией диапазона. Оценивать его нужно вместе с симптомами и другими показателями.',
    'выше референса' =>
      'Значение выше указанного лабораторией диапазона. Само по себе это не устанавливает диагноз.',
    'в пределах референса' =>
      'Значение находится внутри диапазона, указанного лабораторией.',
    _ => 'Автоматически сопоставить значение с референсом не удалось.',
  };
}

Future<void> _addLab(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  LabResult? lab,
]) async {
  final initialMarker = lab?.marker ?? 'глюкоза';
  final marker = TextEditingController(text: initialMarker);
  final value = TextEditingController(text: lab?.value ?? '');
  final unit = TextEditingController(
    text: lab?.unit.isNotEmpty == true
        ? lab!.unit
        : _defaultManualLabUnit(initialMarker),
  );
  final reference = TextEditingController(
    text: lab?.reference.isNotEmpty == true
        ? lab!.reference
        : _defaultManualLabReference(initialMarker),
  );
  final date = TextEditingController(
    text: dateInputText(lab?.date ?? state.today.date),
  );
  final notes = TextEditingController(text: lab?.notes ?? '');
  var markerPreset = marker.text;
  var unitPreset = unit.text;
  var referencePreset = reference.text;
  var needsAttention = lab?.needsAttention ?? false;
  final pendingCustomOptions = <CustomOption>[];
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final markerItems = {
          'глюкоза',
          'холестерин',
          'гемоглобин',
          'ферритин',
          'витамин D',
          'ТТГ',
          'С-реактивный белок',
          'АЛТ',
          'АСТ',
          'креатинин',
          'мочевина',
          ...state.customLabels('labMarkers'),
          ...pendingCustomOptions
              .where((item) => item.group == 'labMarkers')
              .map((item) => item.label),
        }.toList();
        final unitItems = {
          'ммоль/л',
          'мг/дл',
          'г/л',
          'мг/л',
          'мкг/л',
          'мкмоль/л',
          'нг/мл',
          'мЕд/л',
          'Ед/л',
          '%',
          ...state.customLabels('labUnits'),
          ...pendingCustomOptions
              .where((item) => item.group == 'labUnits')
              .map((item) => item.label),
        }.toList();
        final referenceItems = {
          _defaultManualLabReference(markerPreset),
          'см. бланк лаборатории',
          'индивидуально',
          'в норме',
          'ниже референса',
          'выше референса',
          'по назначению врача',
          ...state.customLabels('labReferences'),
          ...pendingCustomOptions
              .where((item) => item.group == 'labReferences')
              .map((item) => item.label),
        }.where((item) => item.trim().isNotEmpty).toList();
        if (!unitItems.contains(unitPreset)) {
          unitItems.insert(0, unitPreset);
        }
        if (!referenceItems.contains(referencePreset)) {
          referenceItems.insert(0, referencePreset);
        }
        if (!markerItems.contains(markerPreset)) {
          markerItems.insert(0, markerPreset);
        }
        return AlertDialog(
          title: Text(lab == null ? 'Новый анализ' : 'Редактировать анализ'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: markerPreset,
                    decoration: const InputDecoration(labelText: 'Показатель'),
                    items: [
                      for (final item in markerItems)
                        DropdownMenuItem(value: item, child: Text(item)),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (selected) async {
                      if (selected == null) {
                        return;
                      }
                      if (selected == _customDropdownValue) {
                        final custom = await _promptCustomOptionLabel(
                          context,
                          title: 'Свой показатель',
                          label: 'Показатель анализа',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'labMarkers',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() {
                          markerPreset = custom;
                          marker.text = custom;
                        });
                        return;
                      }
                      setDialogState(() {
                        markerPreset = selected;
                        marker.text = selected;
                        final defaultUnit = _defaultManualLabUnit(selected);
                        if (defaultUnit.isNotEmpty) {
                          unitPreset = defaultUnit;
                          unit.text = defaultUnit;
                        }
                        final defaultReference = _defaultManualLabReference(
                          selected,
                        );
                        if (defaultReference.isNotEmpty) {
                          referencePreset = defaultReference;
                          reference.text = defaultReference;
                        }
                      });
                    },
                  ),
                  LocalizedTextField(
                    controller: value,
                    decoration: const InputDecoration(labelText: 'Значение'),
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: unitPreset,
                    decoration: const InputDecoration(labelText: 'Единица'),
                    items: [
                      for (final item in unitItems)
                        DropdownMenuItem(value: item, child: Text(item)),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (selected) async {
                      if (selected == null) {
                        return;
                      }
                      if (selected == _customDropdownValue) {
                        final custom = await _promptCustomOptionLabel(
                          context,
                          title: 'Своя единица',
                          label: 'Единица измерения',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'labUnits',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() {
                          unitPreset = custom;
                          unit.text = custom;
                        });
                        return;
                      }
                      setDialogState(() {
                        unitPreset = selected;
                        unit.text = selected;
                      });
                    },
                  ),
                  LocalizedTextField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: 'Дата анализа',
                      hintText: 'ДД.ММ.ГГГГ',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
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
                    initialValue: referencePreset,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Референс'),
                    items: [
                      for (final item in referenceItems)
                        DropdownMenuItem(value: item, child: Text(item)),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (selected) async {
                      if (selected == null) {
                        return;
                      }
                      if (selected == _customDropdownValue) {
                        final custom = await _promptCustomOptionLabel(
                          context,
                          title: 'Свой референс',
                          label: 'Референс анализа',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'labReferences',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() {
                          referencePreset = custom;
                          reference.text = custom;
                        });
                        return;
                      }
                      setDialogState(() {
                        referencePreset = selected;
                        reference.text = selected;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: needsAttention,
                    title: const Text('Требует внимания'),
                    subtitle: const Text(
                      'Отметьте, если показатель вне референса или требует обсуждения с врачом.',
                    ),
                    onChanged: (value) {
                      setDialogState(() => needsAttention = value);
                    },
                  ),
                  LocalizedTextField(
                    controller: notes,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Заметка'),
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
                if (marker.text.trim().isNotEmpty) {
                  final labDate = dateStorageText(
                    date.text,
                    fallback: state.today.date,
                  );
                  final updatedLab =
                      (lab ??
                              LabResult(
                                id: newId(),
                                marker: marker.text.trim(),
                                value: value.text.trim(),
                                unit: unit.text.trim(),
                                reference: reference.text.trim(),
                                date: labDate,
                                needsAttention: needsAttention,
                                notes: notes.text.trim().isEmpty
                                    ? 'Добавлено вручную, требуется проверка динамики.'
                                    : notes.text.trim(),
                              ))
                          .copyWith(
                            marker: marker.text.trim(),
                            value: value.text.trim(),
                            unit: unit.text.trim(),
                            reference: reference.text.trim(),
                            date: labDate,
                            needsAttention: needsAttention,
                            notes: notes.text.trim().isEmpty
                                ? 'Добавлено вручную, требуется проверка динамики.'
                                : notes.text.trim(),
                          );
                  final labResults = lab == null
                      ? [updatedLab, ...state.labResults]
                      : state.labResults
                            .map(
                              (item) => item.id == lab.id ? updatedLab : item,
                            )
                            .toList();
                  onChanged(
                    state.copyWith(
                      customOptions: [
                        ...pendingCustomOptions,
                        ...state.customOptions,
                      ],
                      labResults: labResults,
                    ),
                  );
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

String _defaultManualLabUnit(String marker) {
  final normalized = marker.toLowerCase();
  if (normalized.contains('глюкоз')) {
    return 'ммоль/л';
  }
  if (normalized.contains('холестерин')) {
    return 'ммоль/л';
  }
  if (normalized.contains('гемоглоб')) {
    return 'г/л';
  }
  if (normalized.contains('ферритин')) {
    return 'нг/мл';
  }
  if (normalized.contains('витамин')) {
    return 'нг/мл';
  }
  if (normalized.contains('ттг')) {
    return 'мЕд/л';
  }
  if (normalized.contains('белок') || normalized == 'crp') {
    return 'мг/л';
  }
  if (normalized.contains('алт') || normalized.contains('аст')) {
    return 'Ед/л';
  }
  if (normalized.contains('креатинин') || normalized.contains('мочевина')) {
    return 'мкмоль/л';
  }
  return '';
}

String _defaultManualLabReference(String marker) {
  final normalized = marker.toLowerCase();
  if (normalized.contains('глюкоз')) {
    return 'обычно 3.9-5.5 натощак';
  }
  if (normalized.contains('холестерин')) {
    return 'см. липидный профиль и риск';
  }
  if (normalized.contains('гемоглоб')) {
    return 'зависит от пола и возраста';
  }
  if (normalized.contains('ферритин')) {
    return 'индивидуально';
  }
  if (normalized.contains('витамин')) {
    return 'индивидуально';
  }
  if (normalized.contains('ттг')) {
    return 'см. бланк лаборатории';
  }
  return 'см. бланк лаборатории';
}
