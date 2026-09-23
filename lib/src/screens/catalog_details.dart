part of '../screens.dart';

Future<void> _showFoodCatalogDetails(
  BuildContext context,
  FoodCatalogItem item,
  String locale, {
  required bool offlineOnly,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(item.titleFor(locale)),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _catalogImage(item.image, offlineOnly: offlineOnly),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(
                    label: '${item.calories} ккал',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  Pill(
                    label: 'Б ${item.protein} г',
                    icon: Icons.egg_alt_outlined,
                  ),
                  Pill(
                    label: 'Ж ${item.fat} г',
                    icon: Icons.water_drop_outlined,
                  ),
                  Pill(label: 'У ${item.carbs} г', icon: Icons.grain_outlined),
                  if (item.sugar > 0) Pill(label: 'сахар ${item.sugar} г'),
                  Pill(label: item.carbType),
                  if (item.fiber > 0) Pill(label: 'клетчатка ${item.fiber} г'),
                  if (item.alcohol.isNotEmpty)
                    Pill(label: 'спирт ${item.alcohol} г'),
                  if (item.salt > 0)
                    Pill(label: 'соль ${item.salt.toStringAsFixed(1)} г'),
                  Pill(label: 'полезность ${item.healthLevel}/10'),
                  Pill(
                    label: '${item.minutes} мин',
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Состав', style: Theme.of(context).textTheme.titleMedium),
              Text(item.composition),
              const SizedBox(height: 12),
              Text(
                'Ингредиенты',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...item.ingredients
                  .split(';')
                  .map((value) => Text('• ${value.trim()}')),
              const SizedBox(height: 12),
              if (item.preparation.isNotEmpty) ...[
                Text(
                  'Приготовление',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ..._catalogTextBlocks(
                  item.preparation,
                  offlineOnly: offlineOnly,
                ),
              ],
              if (item.sourceUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Источник данных',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText(
                  '${item.dataLicense}\n${item.sourceUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (item.history.isNotEmpty)
          LocalizedIconButton(
            tooltip: 'Историческая справка',
            onPressed: () => _showCatalogTextDialog(
              context,
              'Историческая справка',
              item.history,
            ),
            icon: const Icon(Icons.history_edu_outlined),
          ),
        if (item.doctorReview.isNotEmpty)
          LocalizedIconButton(
            tooltip: 'Медицинская справка',
            onPressed: () => _showCatalogTextDialog(
              context,
              'Медицинская справка',
              item.doctorReview,
            ),
            icon: const Icon(Icons.medical_information_outlined),
          ),
        if (item.video.isNotEmpty &&
            (!offlineOnly || !_isRemoteCatalogSource(item.video)))
          LocalizedIconButton(
            tooltip: 'Видео приготовления',
            onPressed: () => _showCatalogVideo(context, item.video),
            icon: const Icon(Icons.play_circle_outline),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppText.get(locale, 'close')),
        ),
      ],
    ),
  );
}

Future<void> _showWorkoutCatalogDetails(
  BuildContext context,
  WorkoutCatalogItem item,
  String locale, {
  required bool offlineOnly,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(item.titleFor(locale)),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _catalogImage(item.image, offlineOnly: offlineOnly),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(label: item.focus, icon: Icons.center_focus_strong),
                  Pill(
                    label: item.equipment,
                    icon: Icons.home_repair_service_outlined,
                  ),
                  Pill(label: item.level, icon: Icons.speed_outlined),
                  Pill(
                    label: '${item.minutes} мин',
                    icon: Icons.timer_outlined,
                  ),
                  Pill(
                    label: '${item.calories} ккал',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  Pill(label: '${item.sets} подходов'),
                ],
              ),
              const SizedBox(height: 14),
              Text(item.description),
              const SizedBox(height: 12),
              Text(
                'Что требуется',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(item.requirements),
              const SizedBox(height: 12),
              Text(
                AppText.get(locale, 'howToDo'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ..._catalogTextBlocks(item.steps, offlineOnly: offlineOnly),
              const SizedBox(height: 12),
              Text(
                AppText.get(locale, 'warning'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(item.warnings),
              if (item.sourceUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Источник данных',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText(
                  '${item.dataLicense}\n${item.sourceUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (item.history.isNotEmpty)
          LocalizedIconButton(
            tooltip: 'Историческая справка',
            onPressed: () => _showCatalogTextDialog(
              context,
              'Историческая справка',
              item.history,
            ),
            icon: const Icon(Icons.history_edu_outlined),
          ),
        if (item.doctorReview.isNotEmpty)
          LocalizedIconButton(
            tooltip: 'Медицинская справка',
            onPressed: () => _showCatalogTextDialog(
              context,
              'Медицинская справка',
              item.doctorReview,
            ),
            icon: const Icon(Icons.medical_information_outlined),
          ),
        if (item.video.isNotEmpty &&
            (!offlineOnly || !_isRemoteCatalogSource(item.video)))
          LocalizedIconButton(
            tooltip: 'Видео',
            onPressed: () => _showCatalogVideo(context, item.video),
            icon: const Icon(Icons.play_circle_outline),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppText.get(locale, 'close')),
        ),
      ],
    ),
  );
}

Widget _catalogImage(String asset, {required bool offlineOnly}) {
  if (asset.trim().isEmpty) {
    return const SizedBox.shrink();
  }
  if (offlineOnly && _isRemoteCatalogSource(asset)) {
    return const InfoTile(
      icon: Icons.cloud_off_outlined,
      title: 'Сетевое изображение скрыто',
      subtitle:
          'Режим «Полностью офлайн» не загружает медиа из внешнего источника.',
    );
  }
  final image = asset.toLowerCase().contains('.svg')
      ? asset.startsWith('https://') || asset.startsWith('http://')
            ? SvgPicture.network(
                asset,
                height: 190,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            : SvgPicture.asset(
                asset,
                height: 190,
                width: double.infinity,
                fit: BoxFit.contain,
              )
      : asset.startsWith('https://') || asset.startsWith('http://')
      ? Image.network(
          asset,
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              height: 190,
              child: Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        )
      : Image.asset(
          asset,
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
  return ClipRRect(borderRadius: BorderRadius.circular(8), child: image);
}

List<Widget> _catalogTextBlocks(String text, {required bool offlineOnly}) {
  final result = <Widget>[];
  final mediaPattern = RegExp(r'^\[(.*?);"(.*?)"\]$|^\[(.*?);(.*?)\]$');
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    final match = mediaPattern.firstMatch(line);
    if (match != null) {
      final caption = (match.group(1) ?? match.group(3) ?? '').trim();
      final asset = (match.group(2) ?? match.group(4) ?? '').trim();
      if (_isCatalogVideo(asset)) {
        final blocked = offlineOnly && _isRemoteCatalogSource(asset);
        result.add(
          Builder(
            builder: (context) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                blocked ? Icons.cloud_off_outlined : Icons.play_circle_outline,
              ),
              title: Text(caption.isEmpty ? 'Видео этапа' : caption),
              subtitle: Text(
                blocked
                    ? 'Сетевое видео отключено офлайн-режимом'
                    : 'Открыть видео этапа',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: blocked ? null : () => _showCatalogVideo(context, asset),
            ),
          ),
        );
        continue;
      }
      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _catalogImage(asset, offlineOnly: offlineOnly),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(caption, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      );
    } else {
      result.add(
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(line)),
      );
    }
  }
  return result;
}

Future<void> _showCatalogTextDialog(
  BuildContext context,
  String title,
  String body,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: Text(body)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

Future<void> _showCatalogVideo(BuildContext context, String source) async {
  await _activeCatalogVideoController?.pause();
  await _activeCatalogVideoController?.dispose();
  _activeCatalogVideoController = null;
  final controller = _isRemoteCatalogSource(source)
      ? VideoPlayerController.networkUrl(Uri.parse(source))
      : File(source).existsSync()
      ? VideoPlayerController.file(File(source))
      : VideoPlayerController.asset(source);
  _activeCatalogVideoController = controller;
  try {
    await controller.initialize();
    await controller.play();
  } catch (error) {
    if (identical(_activeCatalogVideoController, controller)) {
      _activeCatalogVideoController = null;
    }
    await controller.dispose();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть видео: $error')),
      );
    }
    return;
  }
  if (!context.mounted) {
    if (identical(_activeCatalogVideoController, controller)) {
      _activeCatalogVideoController = null;
    }
    await controller.dispose();
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Видео'),
        content: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        actions: [
          LocalizedIconButton(
            tooltip: controller.value.isPlaying ? 'Пауза' : 'Воспроизвести',
            onPressed: () async {
              if (controller.value.isPlaying) {
                await controller.pause();
              } else {
                await controller.play();
              }
              setDialogState(() {});
            },
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    ),
  );
  await controller.pause();
  if (identical(_activeCatalogVideoController, controller)) {
    _activeCatalogVideoController = null;
  }
  await controller.dispose();
}

bool _isRemoteCatalogSource(String source) {
  final lower = source.trim().toLowerCase();
  return lower.startsWith('https://') || lower.startsWith('http://');
}

bool _isCatalogVideo(String source) {
  final path = Uri.tryParse(source)?.path.toLowerCase() ?? source.toLowerCase();
  return const ['.mp4', '.m4v', '.mov', '.webm', '.m3u8'].any(path.endsWith);
}

Future<void> _showExerciseDetails(
  BuildContext context,
  Exercise item,
  String locale,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(item.titleFor(locale)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(
                    label: item.focusFor(locale),
                    icon: Icons.center_focus_strong,
                  ),
                  Pill(
                    label: item.equipmentFor(locale),
                    icon: Icons.home_repair_service_outlined,
                  ),
                  Pill(
                    label: item.levelFor(locale),
                    icon: Icons.speed_outlined,
                  ),
                  Pill(
                    label: '${item.minutes} ${AppText.get(locale, 'minShort')}',
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppText.get(locale, 'howToDo'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(item.instructionsFor(locale)),
              const SizedBox(height: 16),
              Text(
                AppText.get(locale, 'warning'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(item.warningFor(locale)),
              const SizedBox(height: 16),
              const MedicalDisclaimerBanner(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppText.get(locale, 'close')),
        ),
      ],
    ),
  );
}

Future<void> _showWorkoutDetails(
  BuildContext context,
  WorkoutSession item,
  String locale,
) async {
  final exercises = item.exerciseIds
      .map(
        (id) => exerciseCatalog
            .where((exercise) => exercise.id == id)
            .cast<Exercise?>()
            .firstOrNull,
      )
      .whereType<Exercise>()
      .toList();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(item.title),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(label: item.focus, icon: Icons.center_focus_strong),
                  Pill(label: item.intensity, icon: Icons.speed_outlined),
                  Pill(
                    label: '${item.minutes} ${AppText.get(locale, 'minShort')}',
                    icon: Icons.timer_outlined,
                  ),
                  Pill(
                    label: item.scheduledDate,
                    icon: Icons.calendar_today_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final exercise in exercises)
                InfoTile(
                  icon: Icons.fitness_center_outlined,
                  title: exercise.titleFor(locale),
                  subtitle:
                      '${exercise.instructionsFor(locale)}\n${exercise.warningFor(locale)}',
                  onTap: () => _showExerciseDetails(context, exercise, locale),
                ),
              if (exercises.isEmpty)
                Text(AppText.get(locale, 'noWorkoutExercises')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}
