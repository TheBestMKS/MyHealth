part of '../screens.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late final HealthBleService _bleService;
  var _scanning = false;
  var _status = 'Bluetooth не запущен';
  String? _syncingDeviceId;

  @override
  void initState() {
    super.initState();
    _bleService = HealthBleService();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return PageBand(
      title: AppText.get(state.localeCode, 'devices'),
      subtitle: 'Браслеты, часы, HealthKit, Health Connect и ручной режим',
      trailing: Wrap(
        spacing: 8,
        children: [
          LocalizedIconButton.filledTonal(
            tooltip: 'Добавить устройство вручную',
            onPressed: _addManualDevice,
            icon: const Icon(Icons.add),
          ),
          LocalizedIconButton.filled(
            tooltip: _scanning ? 'Остановить сканирование' : 'Сканировать BLE',
            onPressed: _scanning ? _stopScan : _startScan,
            icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
          ),
        ],
      ),
      children: [
        HealthPlatformPanel(state: state, onChanged: widget.onChanged),
        _DeviceCompatibilityPanel(state: state),
        InfoTile(
          icon: Icons.bluetooth_outlined,
          title: 'Bluetooth',
          subtitle: _status,
        ),
        StreamBuilder<List<HealthBleDevice>>(
          stream: _bleService.devicesStream,
          initialData: _bleService.currentDevices,
          builder: (context, snapshot) {
            final devices = snapshot.data ?? const <HealthBleDevice>[];
            if (devices.isEmpty) {
              return const InfoTile(
                icon: Icons.search_off_outlined,
                title: 'Найденных устройств пока нет',
                subtitle:
                    'Включите Bluetooth, переведите браслет или датчик в режим сопряжения и запустите сканирование.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Найденные BLE-устройства'),
                ...devices.map(
                  (device) => InfoTile(
                    icon: Icons.bluetooth_connected_outlined,
                    title: device.name.isEmpty ? device.deviceId : device.name,
                    subtitle:
                        'RSSI: ${device.rssi ?? 'нет'} · сервисы: ${device.services.join(', ')}',
                    trailing: FilledButton(
                      onPressed: () => _connectDevice(device),
                      child: const Text('Подключить'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SectionTitle('Добавленные пользователем'),
        ...state.devices.map(
          (item) => InfoTile(
            icon: item.enabled
                ? Icons.watch_outlined
                : Icons.watch_off_outlined,
            title: '${item.title} · ${item.type}',
            subtitle:
                'Статус: ${item.status} · ${item.protocol}\nСинхронизация: ${item.lastSync}\nБатарея: ${item.batteryPercent == null ? 'нет данных' : '${item.batteryPercent}%'} · RSSI: ${item.rssi ?? 'нет'}\nФункции: ${item.features.isEmpty ? item.permissions : item.features.join(', ')}\nПрофиль BLE: ${item.bleMappings.isEmpty ? 'стандартный' : '${item.bleMappings.length} пользовательских характеристик'}\nСервисы: ${item.services.join(', ')}${item.lastError.isEmpty ? '' : '\nОшибки: ${item.lastError}'}',
            onTap: () => _editManualDevice(item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => widget.onChanged(
                state.copyWith(
                  devices: state.devices
                      .where((candidate) => candidate.id != item.id)
                      .toList(),
                ),
              ),
            ),
            trailing: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LocalizedIconButton.filledTonal(
                  tooltip: 'Редактировать устройство',
                  onPressed: () => _editManualDevice(item),
                  icon: const Icon(Icons.edit_outlined),
                ),
                LocalizedIconButton.filledTonal(
                  tooltip: 'Профиль BLE',
                  onPressed: item.protocol == 'BLE'
                      ? () => _editBleProfile(item)
                      : null,
                  icon: const Icon(Icons.tune_outlined),
                ),
                LocalizedIconButton.filledTonal(
                  tooltip: 'Синхронизировать данные',
                  onPressed:
                      _syncingDeviceId == item.id ||
                          item.protocol != 'BLE' ||
                          item.deviceId.isEmpty
                      ? null
                      : () => _syncDevice(item),
                  icon: _syncingDeviceId == item.id
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
                Switch(
                  value: item.enabled,
                  onChanged: (value) {
                    final devices = state.devices
                        .map(
                          (candidate) => candidate.id == item.id
                              ? candidate.copyWith(
                                  enabled: value,
                                  lastSync: value ? 'только что' : 'отключено',
                                  status: value ? 'connected' : 'disconnected',
                                )
                              : candidate,
                        )
                        .toList();
                    widget.onChanged(state.copyWith(devices: devices));
                  },
                ),
              ],
            ),
          ),
        ),
        const InfoTile(
          icon: Icons.edit_note_outlined,
          title: 'Полностью ручной режим',
          subtitle:
              'Приложение работает без браслета: вес, сон, шаги, еда и тренировки можно вводить вручную.',
        ),
      ],
    );
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _status = 'Запрашиваем разрешения и ищем устройства...';
    });
    try {
      await _bleService.startScan();
      final state = await _bleService.availabilityLabel();
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Сканирование активно · $state');
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Bluetooth scan',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _scanning = false;
        _status = 'Ошибка Bluetooth: $error';
      });
    }
  }

  Future<void> _stopScan() async {
    await _bleService.stopScan();
    if (!mounted) {
      return;
    }
    setState(() {
      _scanning = false;
      _status = 'Сканирование остановлено';
    });
  }

  Future<void> _connectDevice(HealthBleDevice device) async {
    setState(
      () => _status =
          'Подключаем ${device.name.isEmpty ? device.deviceId : device.name}...',
    );
    try {
      final connection = await _bleService.connect(device);
      final devices = [
        connection,
        ...widget.state.devices.where(
          (item) => item.deviceId != connection.deviceId,
        ),
      ];
      widget.onChanged(widget.state.copyWith(devices: devices));
      if (!mounted) {
        return;
      }
      setState(() {
        _scanning = false;
        _status = 'Подключено: ${connection.title}';
      });
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Bluetooth connection',
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Не удалось подключить устройство: $error');
    }
  }

  Future<void> _addManualDevice() async {
    final device = await editDeviceConnectionDialog(context);
    if (device == null) {
      return;
    }
    final devices = [
      device,
      ...widget.state.devices.where(
        (item) =>
            item.id != device.id &&
            (device.deviceId.isEmpty || item.deviceId != device.deviceId),
      ),
    ];
    widget.onChanged(widget.state.copyWith(devices: devices));
    if (!mounted) {
      return;
    }
    setState(() => _status = 'Добавлено устройство: ${device.title}');
  }

  Future<void> _editManualDevice(DeviceConnection device) async {
    final updated = await editDeviceConnectionDialog(context, device: device);
    if (updated == null) {
      return;
    }
    final devices = widget.state.devices
        .map((item) => item.id == device.id ? updated : item)
        .toList();
    widget.onChanged(widget.state.copyWith(devices: devices));
    if (!mounted) {
      return;
    }
    setState(() => _status = 'Обновлено устройство: ${updated.title}');
  }

  Future<void> _syncDevice(DeviceConnection device) async {
    setState(() {
      _syncingDeviceId = device.id;
      _status = 'Синхронизация ${device.title}...';
    });
    try {
      final result = await _bleService.sync(device);
      final syncedAt = todayKey();
      var nextState = widget.state;
      final metrics = nextState.metricsFor(syncedAt);
      var syncedMetrics = metrics;
      var metricsChanged = false;
      if (result.weightKg != null) {
        syncedMetrics = syncedMetrics.copyWith(weightKg: result.weightKg);
        metricsChanged = true;
      }
      if (result.energyKcal != null) {
        syncedMetrics = syncedMetrics.copyWith(
          activeCalories: result.energyKcal! > syncedMetrics.activeCalories
              ? result.energyKcal!
              : syncedMetrics.activeCalories,
        );
        metricsChanged = true;
      }
      if (result.elapsedSeconds != null) {
        final minutes = (result.elapsedSeconds! / 60).ceil();
        syncedMetrics = syncedMetrics.copyWith(
          workoutMinutes: minutes > syncedMetrics.workoutMinutes
              ? minutes
              : syncedMetrics.workoutMinutes,
        );
        metricsChanged = true;
      }
      for (final measurement in result.mappedMeasurements) {
        final updated = _applyBleMappedMetric(syncedMetrics, measurement);
        if (updated != null) {
          syncedMetrics = updated;
          metricsChanged = true;
        }
      }
      if (metricsChanged) {
        nextState = nextState.updateMetricsFor(syncedAt, syncedMetrics);
      }

      final labResults = [
        ..._bleLabResults(result, device.title, syncedAt),
        ...nextState.labResults,
      ];
      final devices = nextState.devices
          .map(
            (item) => item.id == device.id
                ? item.copyWith(
                    enabled: true,
                    status: 'connected',
                    lastSync: result.summary,
                    services: result.readServices.isEmpty
                        ? item.services
                        : result.readServices,
                    rssi: result.rssi,
                    batteryPercent:
                        result.batteryPercent ??
                        _mappedBatteryPercent(result.mappedMeasurements),
                    lastError: result.errors.join('; '),
                  )
                : item,
          )
          .toList();

      widget.onChanged(
        nextState.copyWith(labResults: labResults, devices: devices),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _syncingDeviceId = null;
        _status = 'Синхронизация завершена: ${result.summary}';
      });
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Bluetooth synchronization',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _syncingDeviceId = null;
        _status = 'Ошибка синхронизации: $error';
      });
    }
  }

  Future<void> _runBleCommand(
    DeviceConnection device,
    BleWriteCommand command,
  ) async {
    setState(() {
      _syncingDeviceId = device.id;
      _status = 'Выполняем BLE-команду ${command.title}...';
    });
    try {
      await _bleService.writeCommand(device, command);
      final devices = widget.state.devices
          .map(
            (item) => item.id == device.id
                ? item.copyWith(
                    enabled: true,
                    status: 'connected',
                    lastSync: 'Команда "${command.title}" выполнена',
                    lastError: '',
                  )
                : item,
          )
          .toList();
      widget.onChanged(widget.state.copyWith(devices: devices));
      if (!mounted) {
        return;
      }
      setState(() {
        _syncingDeviceId = null;
        _status = 'BLE-команда выполнена: ${command.title}';
      });
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Bluetooth command',
      );
      final devices = widget.state.devices
          .map(
            (item) => item.id == device.id
                ? item.copyWith(lastError: '${command.title}: $error')
                : item,
          )
          .toList();
      widget.onChanged(widget.state.copyWith(devices: devices));
      if (!mounted) {
        return;
      }
      setState(() {
        _syncingDeviceId = null;
        _status = 'Ошибка BLE-команды: $error';
      });
    }
  }

  Future<void> _editBleProfile(DeviceConnection device) async {
    var current = device;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void updateDevice(DeviceConnection updated) {
            current = updated;
            final devices = widget.state.devices
                .map((item) => item.id == updated.id ? updated : item)
                .toList();
            widget.onChanged(widget.state.copyWith(devices: devices));
            setSheetState(() {});
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BLE-профиль: ${current.title}',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Добавьте характеристики и команды устройства, если производитель использует нестандартные UUID. Команды могут включать закрытый браслет, запускать измерение или открывать поток данных перед синхронизацией.',
                      style: Theme.of(sheetContext).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ActionRow(
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final mapping = await _editBleMappingDialog(
                              sheetContext,
                              services: current.services,
                            );
                            if (mapping == null) {
                              return;
                            }
                            final mappings = [mapping, ...current.bleMappings];
                            updateDevice(
                              current.copyWith(
                                bleMappings: mappings,
                                features: _featuresWithBleMappings(
                                  current.features,
                                  mappings,
                                  current.bleCommands,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Характеристика'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final command = await _editBleCommandDialog(
                              sheetContext,
                              services: current.services,
                            );
                            if (command == null) {
                              return;
                            }
                            final commands = [command, ...current.bleCommands];
                            updateDevice(
                              current.copyWith(
                                bleCommands: commands,
                                features: _featuresWithBleMappings(
                                  current.features,
                                  current.bleMappings,
                                  commands,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.output_outlined),
                          label: const Text('Команда'),
                        ),
                      ],
                    ),
                    SectionTitle('Характеристики чтения'),
                    if (current.bleMappings.isEmpty)
                      const InfoTile(
                        icon: Icons.info_outline,
                        title: 'Пользовательских характеристик пока нет',
                        subtitle:
                            'Стандартные GATT-сервисы читаются автоматически. Для закрытых или редких устройств добавьте UUID вручную.',
                      )
                    else
                      ...current.bleMappings.map(
                        (mapping) => InfoTile(
                          icon: mapping.enabled
                              ? Icons.sensors_outlined
                              : Icons.sensors_off_outlined,
                          title:
                              '${mapping.title} · ${_bleMetricLabel(mapping.metric)}',
                          subtitle:
                              'Сервис ${mapping.serviceUuid} · характеристика ${mapping.characteristicUuid}\nПарсер: ${_bleParserLabel(mapping.parser)} · x${mapping.scale} + ${mapping.offset}${mapping.unit.isEmpty ? '' : ' · ${mapping.unit}'}',
                          onTap: () async {
                            final updated = await _editBleMappingDialog(
                              sheetContext,
                              services: current.services,
                              mapping: mapping,
                            );
                            if (updated == null) {
                              return;
                            }
                            final mappings = current.bleMappings
                                .map(
                                  (item) =>
                                      item.id == mapping.id ? updated : item,
                                )
                                .toList();
                            updateDevice(
                              current.copyWith(
                                bleMappings: mappings,
                                features: _featuresWithBleMappings(
                                  current.features,
                                  mappings,
                                  current.bleCommands,
                                ),
                              ),
                            );
                          },
                          onLongPress: () => _confirmDelete(
                            sheetContext,
                            title: mapping.title,
                            onDelete: () {
                              final mappings = current.bleMappings
                                  .where((item) => item.id != mapping.id)
                                  .toList();
                              updateDevice(
                                current.copyWith(
                                  bleMappings: mappings,
                                  features: _featuresWithBleMappings(
                                    current.features,
                                    mappings,
                                    current.bleCommands,
                                  ),
                                ),
                              );
                            },
                          ),
                          trailing: Switch(
                            value: mapping.enabled,
                            onChanged: (value) {
                              final mappings = current.bleMappings
                                  .map(
                                    (item) => item.id == mapping.id
                                        ? item.copyWith(enabled: value)
                                        : item,
                                  )
                                  .toList();
                              updateDevice(
                                current.copyWith(
                                  bleMappings: mappings,
                                  features: _featuresWithBleMappings(
                                    current.features,
                                    mappings,
                                    current.bleCommands,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SectionTitle('Команды записи'),
                    if (current.bleCommands.isEmpty)
                      const InfoTile(
                        icon: Icons.output_outlined,
                        title: 'BLE-команд пока нет',
                        subtitle:
                            'Добавьте init, start measurement или control-point команду, если устройство требует записи перед чтением.',
                      )
                    else
                      ...current.bleCommands.map(
                        (command) => InfoTile(
                          icon: command.enabled
                              ? Icons.output_outlined
                              : Icons.block_outlined,
                          title: command.title,
                          subtitle:
                              'Сервис ${command.serviceUuid} · характеристика ${command.characteristicUuid}\nPayload ${command.payloadHex} · ${command.withoutResponse ? 'без ответа' : 'с ответом'} · ${command.runBeforeSync ? 'перед синхронизацией' : 'ручной запуск'} · задержка ${command.delayMs} мс',
                          onTap: () async {
                            final updated = await _editBleCommandDialog(
                              sheetContext,
                              services: current.services,
                              command: command,
                            );
                            if (updated == null) {
                              return;
                            }
                            final commands = current.bleCommands
                                .map(
                                  (item) =>
                                      item.id == command.id ? updated : item,
                                )
                                .toList();
                            updateDevice(
                              current.copyWith(
                                bleCommands: commands,
                                features: _featuresWithBleMappings(
                                  current.features,
                                  current.bleMappings,
                                  commands,
                                ),
                              ),
                            );
                          },
                          onLongPress: () => _confirmDelete(
                            sheetContext,
                            title: command.title,
                            onDelete: () {
                              final commands = current.bleCommands
                                  .where((item) => item.id != command.id)
                                  .toList();
                              updateDevice(
                                current.copyWith(
                                  bleCommands: commands,
                                  features: _featuresWithBleMappings(
                                    current.features,
                                    current.bleMappings,
                                    commands,
                                  ),
                                ),
                              );
                            },
                          ),
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              LocalizedIconButton(
                                tooltip: 'Выполнить команду',
                                onPressed: current.deviceId.isEmpty
                                    ? null
                                    : () => _runBleCommand(current, command),
                                icon: const Icon(Icons.play_arrow_outlined),
                              ),
                              Switch(
                                value: command.enabled,
                                onChanged: (value) {
                                  final commands = current.bleCommands
                                      .map(
                                        (item) => item.id == command.id
                                            ? item.copyWith(enabled: value)
                                            : item,
                                      )
                                      .toList();
                                  updateDevice(
                                    current.copyWith(
                                      bleCommands: commands,
                                      features: _featuresWithBleMappings(
                                        current.features,
                                        current.bleMappings,
                                        commands,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeviceCompatibilityPanel extends StatelessWidget {
  const _DeviceCompatibilityPanel({required this.state});

  final HealthAppState state;

  @override
  Widget build(BuildContext context) {
    final connectedServices = state.devices
        .expand((item) => item.services)
        .map((item) => item.toLowerCase())
        .toSet();
    bool has(String uuid) => connectedServices.any(
      (item) => item.replaceAll('-', '').contains(uuid),
    );
    final directProfiles = <String>[
      if (has('180d')) 'пульс',
      if (has('1810')) 'давление',
      if (has('181d')) 'вес',
      if (has('181b')) 'состав тела',
      if (has('1822')) 'SpO₂',
      if (has('1808') || has('181f')) 'глюкоза',
      if (has('1826')) 'тренажёр FTMS',
      if (has('1814')) 'бег/каденс',
      if (has('1818')) 'веломощность',
    ];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('Совместимость и безопасность'),
        subtitle: Text(
          directProfiles.isEmpty
              ? 'Проверьте поддерживаемый путь подключения перед покупкой устройства'
              : 'Обнаружены профили: ${directProfiles.join(', ')}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const InfoTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Часы и фитнес-браслеты',
            subtitle:
                'Samsung, Fitbit, Garmin, Xiaomi, Huawei, Oura, WHOOP и Withings обычно передают данные через фирменное приложение в Health Connect или Apple Health. Прямой BLE доступен только при открытом стандартном профиле.',
          ),
          const InfoTile(
            icon: Icons.fitness_center_outlined,
            title: 'Тренажёры',
            subtitle:
                'Поддерживаются стандартные FTMS-беговые дорожки, велотренажёры и гребные тренажёры, а также Running Speed and Cadence и Cycling Power.',
          ),
          const InfoTile(
            icon: Icons.bloodtype_outlined,
            title: 'Глюкометры и CGM',
            subtitle:
                'Чтение Bluetooth Glucose и CGM, а также глюкозы из Health Connect/Apple Health. Значения нормализуются в ммоль/л и отмечаются для проверки.',
          ),
          const InfoTile(
            icon: Icons.lock_outline,
            title: 'Инсулиновые помпы — только безопасный журнал',
            subtitle:
                'BLE-команды к CGM и системам доставки инсулина заблокированы. Дозу и управление помпой выполняют только сертифицированное устройство и назначивший специалист.',
          ),
          const InfoTile(
            icon: Icons.bluetooth_outlined,
            title: 'Другие медицинские датчики',
            subtitle:
                'Поддерживаются стандартные профили пульса, давления, веса, состава тела, термометра и пульсоксиметра. Для открытого UUID производителя можно настроить чтение и масштабирование вручную.',
          ),
        ],
      ),
    );
  }
}
