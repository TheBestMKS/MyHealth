part of '../screens.dart';

class HealthPlatformPanel extends StatefulWidget {
  const HealthPlatformPanel({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  State<HealthPlatformPanel> createState() => _HealthPlatformPanelState();
}

class _HealthPlatformPanelState extends State<HealthPlatformPanel> {
  late final HealthPlatformService _service;
  late Future<HealthPlatformAvailability> _availability;
  HealthPlatformSyncResult? _lastResult;
  var _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = HealthPlatformService();
    _availability = _service.checkAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Системное хранилище здоровья'),
        FutureBuilder<HealthPlatformAvailability>(
          future: _availability,
          builder: (context, snapshot) {
            final availability = snapshot.data;
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final failed = snapshot.hasError;
            return InfoTile(
              icon: Icons.health_and_safety_outlined,
              title: availability?.provider ?? 'Health Connect / Apple Health',
              subtitle: failed
                  ? 'Не удалось проверить доступность: ${snapshot.error}'
                  : loading
                  ? 'Проверяем доступность...'
                  : availability!.message,
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (availability?.installRequired == true)
                    LocalizedIconButton.filledTonal(
                      tooltip: 'Установить Health Connect',
                      onPressed: _install,
                      icon: const Icon(Icons.install_mobile_outlined),
                    ),
                  LocalizedIconButton.filled(
                    tooltip: 'Запросить разрешения и синхронизировать',
                    onPressed: availability?.supported == true && !_syncing
                        ? _synchronize
                        : null,
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                  ),
                ],
              ),
            );
          },
        ),
        if (_error != null)
          InfoTile(
            icon: Icons.error_outline,
            title: 'Синхронизация не выполнена',
            subtitle: _error!,
          ),
        if (_lastResult case final result?)
          InfoTile(
            icon: Icons.cloud_done_outlined,
            title: 'Импорт завершён · ${result.provider}',
            subtitle:
                '${result.pointCount} записей · ${result.samples.length} дней активности · '
                '${result.sleepRecords.length} записей сна · ${result.measurements.length} показателей\n'
                'Источники: ${result.sourceNames.isEmpty ? 'системное хранилище' : result.sourceNames.join(', ')}',
          ),
      ],
    );
  }

  Future<void> _install() async {
    try {
      await _service.installHealthConnect();
      if (!mounted) return;
      setState(() {
        _error = null;
        _availability = _service.checkAvailability();
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _synchronize() async {
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final result = await _service.synchronize();
      var next = widget.state;
      for (final sample in result.samples) {
        final current = next.metricsFor(sample.date);
        final updated = current.copyWith(
          steps: sample.steps > 0 ? sample.steps : current.steps,
          activeCalories: sample.activeCalories > 0
              ? sample.activeCalories
              : current.activeCalories,
          workoutMinutes: sample.workoutMinutes > 0
              ? sample.workoutMinutes
              : current.workoutMinutes,
          weightKg: sample.weightKg ?? current.weightKg,
        );
        next = next.updateMetricsFor(sample.date, updated);
      }

      final sleepIds = result.sleepRecords.map((item) => item.id).toSet();
      final sleeps = [
        ...result.sleepRecords,
        ...next.sleepRecords.where((item) => !sleepIds.contains(item.id)),
      ];
      final measurementIds = result.measurements.map((item) => item.id).toSet();
      final labs = [
        ...result.measurements.map(_healthMeasurementToLab),
        ...next.labResults.where((item) => !measurementIds.contains(item.id)),
      ];
      final now = DateTime.now();
      final syncLabel =
          '${displayDateKey(todayKey(now))} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final platformDevice = DeviceConnection(
        id: 'platform-health',
        title: result.provider,
        type: 'Платформенное здоровье',
        enabled: true,
        lastSync: syncLabel,
        permissions: 'чтение выбранных пользователем показателей',
        protocol: result.provider,
        status: 'connected',
        features: const [
          'шаги',
          'активные калории',
          'тренировки',
          'вес',
          'состав тела',
          'сон',
          'пульс',
          'вариабельность пульса',
          'давление',
          'SpO2',
          'глюкоза',
        ],
      );
      final devices = [
        platformDevice,
        ...next.devices.where((item) => item.id != platformDevice.id),
      ];
      next = next.copyWith(
        sleepRecords: sleeps,
        labResults: labs,
        devices: devices,
      );
      widget.onChanged(next);
      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Данные ${result.provider} синхронизированы.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _healthErrorText(error));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

LabResult _healthMeasurementToLab(HealthMeasurement item) {
  final reference = switch (item.marker) {
    'Пульс' || 'Пульс в покое' => '60-100',
    'Давление систолическое' => '90-139',
    'Давление диастолическое' => '60-89',
    'Насыщение крови кислородом' => '95-100',
    'Температура тела' => '35.5-37.5',
    'Глюкоза крови' => '3.9-10.0',
    'Индекс массы тела' => '18.5-24.9',
    _ => '',
  };
  return LabResult(
    id: item.id,
    marker: item.marker,
    value: item.value,
    unit: item.unit,
    reference: reference,
    date: item.date,
    needsAttention: item.needsAttention,
    notes: 'Автоматически получено из ${item.source}.',
  );
}

String _healthErrorText(Object error) {
  final text = error.toString().replaceFirst('Bad state: ', '');
  if (text.contains('not granted') || text.contains('Доступ')) {
    return 'Разрешение не выдано. Откройте системные настройки здоровья и разрешите чтение нужных показателей.';
  }
  return text;
}
