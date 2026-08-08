part of '../screens.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _query = '';
  final Set<String> _unlockedDocumentIds = {};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final query = _query.trim().toLowerCase();
    final documents = query.isEmpty
        ? state.documents
        : state.documents
              .where((item) => _documentSearchBlob(state, item).contains(query))
              .toList();
    return PageBand(
      title: AppText.get(state.localeCode, 'documents'),
      subtitle: 'Медицинские файлы, фото, PDF и защищённые записи',
      trailing: Wrap(
        spacing: 8,
        children: [
          LocalizedIconButton.filledTonal(
            tooltip: 'Напечатать отчёт для врача',
            onPressed: () => _printDoctorReport(context, state),
            icon: const Icon(Icons.print_outlined),
          ),
          FilledButton.icon(
            onPressed: () => _editDocument(context, state, widget.onChanged),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Документ'),
          ),
        ],
      ),
      children: [
        const MedicalDisclaimerBanner(),
        LocalizedTextField(
          decoration: const InputDecoration(
            labelText: 'Поиск',
            hintText: 'Название, тег, врач, состояние, лекарство, текст',
            prefixIcon: Icon(Icons.search_outlined),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        if (state.documents.isEmpty)
          const InfoTile(
            icon: Icons.folder_open_outlined,
            title: 'Документов пока нет',
            subtitle:
                'Добавьте файл, снимок, выписку, рецепт или заметку вручную.',
          )
        else if (documents.isEmpty)
          const InfoTile(
            icon: Icons.search_off_outlined,
            title: 'Ничего не найдено',
            subtitle: 'Измените запрос или добавьте тег в карточку документа.',
          ),
        ...documents.map(
          (item) => InfoTile(
            icon: item.locked ? Icons.lock_outline : Icons.description_outlined,
            title: '${item.title} · ${item.kind}',
            subtitle: _documentSubtitle(state, item),
            onTap: () => _openDocument(item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () {
                unawaited(
                  DocumentVaultService.instance.deleteStoredFile(item.filePath),
                );
                widget.onChanged(
                  state.copyWith(
                    documents: state.documents
                        .where((candidate) => candidate.id != item.id)
                        .toList(),
                  ),
                );
              },
            ),
            trailing: LocalizedIconButton.filledTonal(
              tooltip: 'Редактировать карточку документа',
              onPressed: () => _editDocumentSecure(item),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openDocument(HealthDocument document) async {
    if (!await _unlockDocument(document)) return;
    if (!mounted) return;
    if (document.filePath.trim().isEmpty) {
      await _editDocument(context, widget.state, widget.onChanged, document);
      return;
    }
    try {
      final file = await DocumentVaultService.instance.materialize(
        document.filePath,
      );
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isEmpty
                  ? 'Не удалось открыть прикреплённый файл.'
                  : result.message,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть защищённый файл: $error')),
      );
    }
  }

  Future<void> _editDocumentSecure(HealthDocument document) async {
    if (!await _unlockDocument(document) || !mounted) return;
    await _editDocument(context, widget.state, widget.onChanged, document);
  }

  Future<bool> _unlockDocument(HealthDocument document) async {
    if (!widget.state.settings.medicalLock ||
        !document.locked ||
        _unlockedDocumentIds.contains(document.id)) {
      return true;
    }
    final settings = widget.state.settings;
    if (settings.biometricEnabled) {
      final valid = await SecurityService.instance.authenticateBiometric();
      if (valid) {
        _unlockedDocumentIds.add(document.id);
        return true;
      }
    }
    if (!settings.pinEnabled || settings.pinHash.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Документ защищён. Сначала задайте PIN-код в настройках безопасности.',
            ),
          ),
        );
      }
      return false;
    }
    if (!mounted) return false;
    final pin = TextEditingController();
    String error = '';
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Защищённый документ'),
          content: LocalizedTextField(
            controller: pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 12,
            decoration: InputDecoration(
              labelText: 'PIN-код',
              errorText: error.isEmpty ? null : error,
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final valid = await SecurityService.instance.verifyPin(
                  pin.text,
                  settings.pinHash,
                  settings.pinSalt,
                );
                if (!dialogContext.mounted) return;
                if (valid) {
                  Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(() {
                    error = 'Неверный PIN-код';
                    pin.clear();
                  });
                }
              },
              child: const Text('Открыть'),
            ),
          ],
        ),
      ),
    );
    pin.dispose();
    if (unlocked == true) _unlockedDocumentIds.add(document.id);
    return unlocked == true;
  }
}

Future<void> _printDoctorReport(
  BuildContext context,
  HealthAppState state,
) async {
  try {
    final printed = await Printing.layoutPdf(
      name: 'my_health_report_${state.today.date}.pdf',
      onLayout: (_) => ReportService().buildDoctorPdf(state),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          printed
              ? 'Отчёт передан в системную печать.'
              : 'Печать отчёта отменена.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось напечатать отчёт: $error')),
    );
  }
}

String _documentSearchBlob(HealthAppState state, HealthDocument item) {
  final medicationName = state.medications
      .where((medication) => medication.id == item.linkedMedicationId)
      .map((medication) => medication.name)
      .firstOrNull;
  return [
    item.title,
    item.kind,
    item.date,
    item.notes,
    item.fileName,
    item.filePath,
    item.linkedCondition,
    item.linkedDoctor,
    medicationName ?? '',
    item.searchText,
    ...item.tags,
  ].join(' ').toLowerCase();
}

String _documentSubtitle(HealthAppState state, HealthDocument item) {
  final medicationName = state.medications
      .where((medication) => medication.id == item.linkedMedicationId)
      .map((medication) => medication.name)
      .firstOrNull;
  return [
    formatDisplayDate(item.date, state.settings),
    if (item.tags.isNotEmpty) 'Теги: ${item.tags.join(', ')}',
    if (item.linkedCondition.isNotEmpty) 'Состояние: ${item.linkedCondition}',
    if (medicationName != null) 'Лекарство: $medicationName',
    if (item.linkedDoctor.isNotEmpty) 'Врач: ${item.linkedDoctor}',
    item.notes,
    if (item.fileName.isNotEmpty)
      'Файл в защищённом хранилище: ${item.fileName}'
    else if (!DocumentVaultService.instance.isVaultPath(item.filePath))
      item.filePath,
  ].where((value) => value.trim().isNotEmpty).join('\n');
}

Future<void> _editDocument(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  HealthDocument? document,
]) async {
  final title = TextEditingController(text: document?.title ?? '');
  final date = TextEditingController(
    text: dateInputText(document?.date ?? state.today.date),
  );
  final notes = TextEditingController(text: document?.notes ?? '');
  final filePath = TextEditingController(text: document?.filePath ?? '');
  final tags = TextEditingController(text: document?.tags.join(', ') ?? '');
  final linkedCondition = TextEditingController(
    text: document?.linkedCondition ?? '',
  );
  final linkedDoctor = TextEditingController(
    text: document?.linkedDoctor ?? '',
  );
  final searchText = TextEditingController(text: document?.searchText ?? '');
  var attachedFileName = document?.fileName ?? '';
  final pendingCustomOptions = <CustomOption>[];
  var kind = document?.kind.isNotEmpty == true
      ? document!.kind
      : 'медицинский документ';
  var linkedMedicationId = document?.linkedMedicationId ?? '';
  var locked = document?.locked ?? true;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final kindItems = {
          'медицинский документ',
          'анализ',
          'заключение врача',
          'рецепт',
          'выписка',
          'снимок',
          'страховка',
          'паспорт здоровья',
          'прочее',
          ...state.customLabels('documentKinds'),
          ...pendingCustomOptions
              .where((item) => item.group == 'documentKinds')
              .map((item) => item.label),
        }.where((item) => item.trim().isNotEmpty).toList();
        if (!kindItems.contains(kind)) {
          kindItems.insert(0, kind);
        }

        Future<void> attachMedia({required bool camera}) async {
          final media = camera
              ? await MediaImportService().captureCameraImage()
              : await MediaImportService().pickImageFile(kind: 'document');
          if (!context.mounted) {
            return;
          }
          if (media == null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Импорт отменён')));
            return;
          }
          setDialogState(() {
            filePath.text = media.path;
            attachedFileName = media.name;
            if (title.text.trim().isEmpty) {
              title.text = media.name;
            }
            if (kind == 'прочее') {
              kind = camera ? 'снимок' : 'медицинский документ';
            }
          });
        }

        return AlertDialog(
          title: Text(
            document == null ? 'Добавить документ' : 'Редактировать документ',
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    autofocus: document == null,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: анализ крови от терапевта',
                    ),
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: kind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: [
                      for (final item in kindItems)
                        DropdownMenuItem(value: item, child: Text(item)),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      if (value == _customDropdownValue) {
                        final custom = await _promptCustomOptionLabel(
                          context,
                          title: 'Свой тип документа',
                          label: 'Тип документа',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'documentKinds',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => kind = custom);
                        return;
                      }
                      setDialogState(() => kind = value);
                    },
                  ),
                  LocalizedTextField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: 'Дата',
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
                  LocalizedTextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Заметка',
                      hintText: 'Кратко: врач, результат, что проверить',
                    ),
                  ),
                  LocalizedTextField(
                    controller: filePath,
                    decoration: const InputDecoration(
                      labelText: 'Файл',
                      hintText: 'Можно прикрепить файл или снимок',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                  LocalizedTextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'Теги',
                      hintText: 'через запятую: анализы, кардиолог, отпуск',
                    ),
                  ),
                  LocalizedTextField(
                    controller: linkedCondition,
                    decoration: InputDecoration(
                      labelText: 'Связанное состояние',
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: 'Выбрать состояние',
                        icon: const Icon(Icons.favorite_border),
                        onSelected: (value) =>
                            setDialogState(() => linkedCondition.text = value),
                        itemBuilder: (context) => [
                          for (final item in state.chronicConditions)
                            PopupMenuItem(value: item, child: Text(item)),
                          for (final item in state.medicalEvents)
                            PopupMenuItem(
                              value: item.title,
                              child: Text(item.title),
                            ),
                        ],
                      ),
                    ),
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: linkedMedicationId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Связанное лекарство',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('без лекарства'),
                      ),
                      for (final item in state.medications)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => linkedMedicationId = value ?? ''),
                  ),
                  LocalizedTextField(
                    controller: linkedDoctor,
                    decoration: InputDecoration(
                      labelText: 'Связанный врач',
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: 'Выбрать врача',
                        icon: const Icon(Icons.badge_outlined),
                        onSelected: (value) =>
                            setDialogState(() => linkedDoctor.text = value),
                        itemBuilder: (context) => [
                          for (final item in state.careProviders)
                            PopupMenuItem(
                              value: item.name,
                              child: Text(item.name),
                            ),
                        ],
                      ),
                    ),
                  ),
                  LocalizedTextField(
                    controller: searchText,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Текст для поиска',
                      hintText: 'Ключевые фразы из PDF, фото или выписки',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => attachMedia(camera: false),
                        icon: const Icon(Icons.attach_file_outlined),
                        label: const Text('Выбрать файл'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => attachMedia(camera: true),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Снимок'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Защищённая запись'),
                    subtitle: const Text(
                      'Помечает документ как чувствительный медицинский файл.',
                    ),
                    value: locked,
                    onChanged: (value) => setDialogState(() => locked = value),
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
              onPressed: () async {
                final titleValue = title.text.trim();
                if (titleValue.isEmpty) {
                  return;
                }
                final dateValue = dateStorageText(
                  date.text,
                  fallback: state.today.date,
                );
                final kindValue = kind.trim().isEmpty ? 'прочее' : kind.trim();
                final tagValues = tags.text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toSet()
                    .toList();
                final documentId = document?.id ?? newId();
                final selectedPath = filePath.text.trim();
                final displayFileName = attachedFileName.isNotEmpty
                    ? attachedFileName
                    : selectedPath.split(RegExp(r'[\\/]')).last;
                String storedPath;
                try {
                  storedPath = await DocumentVaultService.instance.importFile(
                    selectedPath,
                    documentId,
                  );
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Не удалось защитить вложение: $error'),
                    ),
                  );
                  return;
                }
                if (document != null &&
                    document.filePath != storedPath &&
                    document.filePath.isNotEmpty) {
                  unawaited(
                    DocumentVaultService.instance.deleteStoredFile(
                      document.filePath,
                    ),
                  );
                }
                final updatedDocument =
                    (document ??
                            HealthDocument(
                              id: documentId,
                              title: titleValue,
                              kind: kindValue,
                              date: dateValue,
                              locked: locked,
                              notes: notes.text.trim(),
                              filePath: storedPath,
                              fileName: displayFileName,
                              tags: tagValues,
                              linkedCondition: linkedCondition.text.trim(),
                              linkedMedicationId: linkedMedicationId,
                              linkedDoctor: linkedDoctor.text.trim(),
                              searchText: searchText.text.trim(),
                            ))
                        .copyWith(
                          title: titleValue,
                          kind: kindValue,
                          date: dateValue,
                          locked: locked,
                          notes: notes.text.trim(),
                          filePath: storedPath,
                          fileName: displayFileName,
                          tags: tagValues,
                          linkedCondition: linkedCondition.text.trim(),
                          linkedMedicationId: linkedMedicationId,
                          linkedDoctor: linkedDoctor.text.trim(),
                          searchText: searchText.text.trim(),
                        );
                final documents = document == null
                    ? [updatedDocument, ...state.documents]
                    : state.documents
                          .map(
                            (item) =>
                                item.id == document.id ? updatedDocument : item,
                          )
                          .toList();
                onChanged(
                  state.copyWith(
                    documents: documents,
                    customOptions: [
                      ...pendingCustomOptions,
                      ...state.customOptions,
                    ],
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    ),
  );
}
