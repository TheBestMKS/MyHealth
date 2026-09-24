part of '../screens.dart';

Future<void> showUniversalCaptureSheet(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
  SectionSelected onSelect, {
  UniversalCaptureStart start = UniversalCaptureStart.composer,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _UniversalCaptureSheet(
        state: state,
        onChanged: onChanged,
        onSelect: onSelect,
        start: start,
      ),
    ),
  );
}

class _UniversalCaptureSheet extends StatefulWidget {
  const _UniversalCaptureSheet({
    required this.state,
    required this.onChanged,
    required this.onSelect,
    required this.start,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;
  final SectionSelected onSelect;
  final UniversalCaptureStart start;

  @override
  State<_UniversalCaptureSheet> createState() => _UniversalCaptureSheetState();
}

class _UniversalCaptureSheetState extends State<_UniversalCaptureSheet> {
  final _controller = TextEditingController();
  final _speech = SpeechInputService.instance;
  final _media = MediaImportService();
  bool _busy = false;
  bool _listening = false;
  bool _voiceInput = false;
  String _status = 'Текст, голос, камера или любой файл';
  String _voicePrefix = '';
  DateTime? _voiceStartedAt;

  @override
  void initState() {
    super.initState();
    if (widget.start != UniversalCaptureStart.composer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            _attach(camera: widget.start == UniversalCaptureStart.camera),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle_outline),
                const SizedBox(width: 10),
                Expanded(
                  child: LocalizedText(
                    'Добавить информацию или спросить',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                LocalizedIconButton(
                  tooltip: 'Ручной дневник',
                  onPressed: _busy ? null : _openManualEntry,
                  icon: const Icon(Icons.tune_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LocalizedTextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText:
                    'Например: выпил 300 мл воды, создай будильник на 07:00',
                helperText: _status,
                prefixIcon: const Icon(Icons.auto_awesome_outlined),
              ),
              onChanged: (_) {
                if (_voiceInput) unawaited(_speech.cancel());
                _voiceInput = false;
              },
              onSubmitted: (_) => _submitText(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                LocalizedIconButton.filledTonal(
                  tooltip: _listening
                      ? 'Остановить голосовой ввод'
                      : 'Голосовой ввод на русском',
                  onPressed: _busy ? null : _toggleSpeech,
                  icon: Icon(_listening ? Icons.stop : Icons.mic_none_outlined),
                ),
                const SizedBox(width: 8),
                LocalizedIconButton.filledTonal(
                  tooltip: 'Сфотографировать',
                  onPressed: _busy ? null : () => _attach(camera: true),
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                const SizedBox(width: 8),
                LocalizedIconButton.filledTonal(
                  tooltip: 'Приложить файл',
                  onPressed: _busy ? null : () => _attach(camera: false),
                  icon: const Icon(Icons.attach_file),
                ),
                const Spacer(),
                LocalizedIconButton.filled(
                  tooltip: 'Отправить',
                  onPressed: _busy ? null : _submitText,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitText() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _busy) return;
    if (_voiceInput) await _speech.stop();
    final voicePath = _voiceInput ? _speech.takeRecordedAudio() : '';
    final duration = _voiceStartedAt == null
        ? 0
        : DateTime.now().difference(_voiceStartedAt!).inSeconds;
    AssistantBackgroundService.instance.enqueueText(
      query: query,
      kind: _voiceInput ? 'voice' : 'text',
      transcript: _voiceInput ? query : '',
      durationSeconds: duration,
      attachmentPath: voicePath,
      attachmentName: voicePath.isEmpty
          ? ''
          : File(voicePath).uri.pathSegments.last,
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSelect(AppSection.assistant);
  }

  Future<void> _toggleSpeech() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _voicePrefix = _controller.text.trim();
    _voiceStartedAt = DateTime.now();
    try {
      await _speech.startRussian(
        onWords: (words, isFinal) {
          if (!mounted) return;
          setState(() {
            _controller.text = [
              _voicePrefix,
              words.trim(),
            ].where((item) => item.isNotEmpty).join(' ');
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
            _voiceInput = true;
            _status = isFinal
                ? 'Голос распознан на русском'
                : 'Слушаю на русском...';
            if (isFinal) _listening = false;
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _listening = false;
              _status = 'Ошибка распознавания: $error';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _listening = true;
          _voiceInput = true;
          _status = 'Слушаю на русском...';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = _shortAssistantError(error));
    }
  }

  Future<void> _attach({required bool camera}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = camera ? 'Открываю камеру...' : 'Открываю файл...';
    });
    try {
      final picked = camera
          ? await _media.captureCameraImage()
          : await _media.pickAnyFile();
      if (picked == null || !mounted) return;
      final intent = await _chooseAttachmentIntent(picked);
      if (intent == null || !mounted) return;
      AssistantBackgroundService.instance.enqueueAttachment(
        media: picked,
        intent: intent,
      );
      Navigator.pop(context);
      widget.onSelect(AppSection.assistant);
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: camera ? 'Universal camera import' : 'Universal file import',
      );
      if (mounted) {
        setState(() => _status = 'Ошибка: ${_shortAssistantError(error)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<AssistantAttachmentIntent?> _chooseAttachmentIntent(
    ImportedMedia media,
  ) {
    return showModalBottomSheet<AssistantAttachmentIntent>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const LocalizedText('Определить автоматически'),
              subtitle: Text(media.name),
              onTap: () =>
                  Navigator.pop(sheetContext, AssistantAttachmentIntent.auto),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const LocalizedText('Еда или напиток'),
              onTap: () =>
                  Navigator.pop(sheetContext, AssistantAttachmentIntent.food),
            ),
            ListTile(
              leading: const Icon(Icons.biotech_outlined),
              title: const LocalizedText('Результаты анализов'),
              onTap: () =>
                  Navigator.pop(sheetContext, AssistantAttachmentIntent.lab),
            ),
            ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const LocalizedText('Рецепт или назначение'),
              onTap: () => Navigator.pop(
                sheetContext,
                AssistantAttachmentIntent.prescription,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const LocalizedText('Только вложить в диалог'),
              onTap: () =>
                  Navigator.pop(sheetContext, AssistantAttachmentIntent.chat),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManualEntry() async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    await showQuickAddDialog(rootContext, widget.state, widget.onChanged);
  }
}

enum UniversalCaptureStart { composer, camera, file }
