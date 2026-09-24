part of '../screens.dart';

Future<void> showErrorLogDialog(
  BuildContext context, {
  ErrorLogService? service,
}) {
  final logService = service ?? ErrorLogService.instance;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final viewer = _ErrorLogViewer(service: logService);
      if (size.width < 700 || size.height < 560) {
        return Dialog.fullscreen(child: viewer);
      }
      final width = size.width < 948 ? size.width - 48 : 900.0;
      final height = size.height < 748 ? size.height - 48 : 700.0;
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: width, height: height, child: viewer),
      );
    },
  );
}

class _ErrorLogViewer extends StatefulWidget {
  const _ErrorLogViewer({required this.service});

  final ErrorLogService service;

  @override
  State<_ErrorLogViewer> createState() => _ErrorLogViewerState();
}

class _ErrorLogViewerState extends State<_ErrorLogViewer> {
  late Future<ErrorLogSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.read();
  }

  void _reload() {
    setState(() => _future = widget.service.read());
  }

  Future<void> _copy() async {
    final snapshot = await widget.service.read();
    if (!mounted || snapshot.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: snapshot.contents));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LocalizedText(
          'Журнал ошибок скопирован.',
          key: Key('error_log_copied_notice'),
        ),
      ),
    );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LocalizedText('Очистить журнал ошибок?'),
        content: const LocalizedText(
          'Записи будут удалены только с этого устройства. Новые ошибки продолжат записываться автоматически.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LocalizedText('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.service.clear();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalizedText(
                          'Журнал ошибок',
                          key: const Key('error_log_title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const LocalizedText(
                          'Хранится локально и автоматически ограничивается по размеру.',
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  LocalizedIconButton(
                    key: const Key('error_log_refresh_button'),
                    tooltip: 'Обновить журнал',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                  LocalizedIconButton(
                    key: const Key('error_log_copy_button'),
                    tooltip: 'Копировать журнал',
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                  LocalizedIconButton(
                    key: const Key('error_log_clear_button'),
                    tooltip: 'Очистить журнал',
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  LocalizedIconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<ErrorLogSnapshot>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: LocalizedText(
                          'Не удалось прочитать журнал: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final value = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            material.Text(
                              value.path,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 3),
                            LocalizedText(
                              'Размер: ${_formatLogSize(value.sizeBytes)}'
                              '${value.modifiedAt == null ? '' : ' · обновлён ${_formatLogTimestamp(value.modifiedAt!)}'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: colors.surfaceContainerLowest,
                          child: value.isEmpty
                              ? const Center(
                                  child: LocalizedText('Журнал ошибок пуст.'),
                                )
                              : SelectionArea(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: material.Text(
                                      value.contents,
                                      key: const Key('error_log_contents'),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLogSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

String _formatLogTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
