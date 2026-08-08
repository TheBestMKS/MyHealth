part of '../screens.dart';

Future<DeviceConnection?> editDeviceConnectionDialog(
  BuildContext context, {
  DeviceConnection? device,
}) async {
  final title = TextEditingController(text: device?.title ?? '');
  final vendor = TextEditingController(text: device?.vendor ?? '');
  final model = TextEditingController(text: device?.model ?? '');
  final deviceId = TextEditingController(text: device?.deviceId ?? '');
  final services = TextEditingController(
    text: device?.services.join(', ') ?? '',
  );
  final features = TextEditingController(
    text: device?.features.join(', ') ?? '',
  );
  var type = _deviceTypeOptions.contains(device?.type)
      ? device!.type
      : 'Bluetooth LE';
  var protocol = _deviceProtocolOptions.contains(device?.protocol)
      ? device!.protocol
      : 'BLE';
  var enabled = device?.enabled ?? true;
  var error = '';

  try {
    return await showDialog<DeviceConnection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            device == null ? 'Добавить устройство' : 'Редактировать устройство',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: браслет для сна',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedDropdownButtonFormField<String>(
                          initialValue: type,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Тип'),
                          items: [
                            for (final item in _deviceTypeOptions)
                              DropdownMenuItem(value: item, child: Text(item)),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => type = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedDropdownButtonFormField<String>(
                          initialValue: protocol,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Протокол',
                          ),
                          items: [
                            for (final item in _deviceProtocolOptions)
                              DropdownMenuItem(value: item, child: Text(item)),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => protocol = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: vendor,
                          decoration: const InputDecoration(
                            labelText: 'Производитель',
                            hintText: 'Garmin, Xiaomi, Omron...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedTextField(
                          controller: model,
                          decoration: const InputDecoration(
                            labelText: 'Модель',
                            hintText: 'Название модели',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: deviceId,
                    decoration: const InputDecoration(
                      labelText: 'BLE deviceId / системный id',
                      hintText: 'Можно оставить пустым и заполнить после скана',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: services,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'BLE-сервисы',
                      hintText: '180d, 180f, fff0',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: features,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Функции',
                      hintText: 'пульс, сон, шаги',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: const Text('Использовать устройство'),
                    subtitle: Text(
                      protocol == 'BLE'
                          ? 'BLE-синхронизация станет доступна после указания deviceId.'
                          : 'Источник хранится в профиле; данные можно вводить вручную или импортировать.',
                    ),
                    onChanged: (value) {
                      setDialogState(() => enabled = value);
                    },
                  ),
                  if (error.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
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
                final normalizedTitle = title.text.trim();
                if (normalizedTitle.isEmpty) {
                  setDialogState(() => error = 'Укажите название устройства.');
                  return;
                }
                final featureList = _parseCommaList(features.text);
                final serviceList = _parseCommaList(services.text);
                final permissions = featureList.isEmpty
                    ? 'пользовательская настройка'
                    : featureList.join(', ');
                Navigator.pop(
                  dialogContext,
                  DeviceConnection(
                    id: device?.id ?? newId(),
                    title: normalizedTitle,
                    type: type,
                    enabled: enabled,
                    lastSync: device?.lastSync ?? 'ожидает настройки',
                    permissions: permissions,
                    deviceId: deviceId.text.trim(),
                    vendor: vendor.text.trim(),
                    model: model.text.trim(),
                    protocol: protocol,
                    services: serviceList,
                    features: _featuresWithBleMappings(
                      featureList,
                      device?.bleMappings ?? const [],
                      device?.bleCommands ?? const [],
                    ),
                    bleMappings: device?.bleMappings ?? const [],
                    bleCommands: device?.bleCommands ?? const [],
                    status: enabled
                        ? (device?.status == 'connected'
                              ? 'connected'
                              : 'configured')
                        : 'disabled',
                    rssi: device?.rssi,
                    batteryPercent: device?.batteryPercent,
                    lastError: device?.lastError ?? '',
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  } finally {
    title.dispose();
    vendor.dispose();
    model.dispose();
    deviceId.dispose();
    services.dispose();
    features.dispose();
  }
}

const _deviceTypeOptions = <String>[
  'Bluetooth LE',
  'Фитнес-браслет',
  'Умные часы',
  'Пульсометр',
  'Весы',
  'Глюкометр',
  'Пульсоксиметр',
  'Тонометр',
  'Health Connect',
  'HealthKit',
  'Ручной источник',
];

const _deviceProtocolOptions = <String>[
  'BLE',
  'Health Connect',
  'HealthKit',
  'Файл/импорт',
  'Manual',
];

List<String> _parseCommaList(String value) {
  return value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

Future<BleWriteCommand?> _editBleCommandDialog(
  BuildContext context, {
  required List<String> services,
  BleWriteCommand? command,
}) async {
  final title = TextEditingController(text: command?.title ?? '');
  final serviceUuid = TextEditingController(text: command?.serviceUuid ?? '');
  final characteristicUuid = TextEditingController(
    text: command?.characteristicUuid ?? '',
  );
  final payloadHex = TextEditingController(text: command?.payloadHex ?? '');
  final delayMs = TextEditingController(text: '${command?.delayMs ?? 250}');
  final serviceOptions = services.toSet().toList()..sort();
  var withoutResponse = command?.withoutResponse ?? false;
  var runBeforeSync = command?.runBeforeSync ?? true;
  var enabled = command?.enabled ?? true;
  var error = '';

  try {
    return await showDialog<BleWriteCommand>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(command == null ? 'Новая BLE-команда' : 'BLE-команда'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: запустить измерение сна',
                    ),
                  ),
                  if (serviceOptions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LocalizedDropdownButtonFormField<String>(
                      initialValue: serviceOptions.contains(serviceUuid.text)
                          ? serviceUuid.text
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Найденный сервис',
                      ),
                      items: [
                        for (final item in serviceOptions.take(40))
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => serviceUuid.text = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: serviceUuid,
                    decoration: const InputDecoration(
                      labelText: 'UUID сервиса',
                      hintText: 'fff0 или полный 128-битный UUID',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: characteristicUuid,
                    decoration: const InputDecoration(
                      labelText: 'UUID характеристики записи',
                      hintText: 'fff2 или control point UUID',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: payloadHex,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Payload, hex',
                      hintText: '01 00 FF или 0x01,0x00,0xFF',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: delayMs,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Задержка после записи, мс',
                      hintText: '250',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: withoutResponse,
                    title: const Text('Write without response'),
                    subtitle: const Text(
                      'Включите для командных характеристик без подтверждения.',
                    ),
                    onChanged: (value) {
                      setDialogState(() => withoutResponse = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: runBeforeSync,
                    title: const Text('Выполнять перед синхронизацией'),
                    subtitle: const Text(
                      'Подходит для init/control-point команд закрытых браслетов.',
                    ),
                    onChanged: (value) {
                      setDialogState(() => runBeforeSync = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: const Text('Команда включена'),
                    onChanged: (value) {
                      setDialogState(() => enabled = value);
                    },
                  ),
                  if (error.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
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
                final service = serviceUuid.text.trim();
                final characteristic = characteristicUuid.text.trim();
                final normalizedPayload = _normalizeBlePayloadHex(
                  payloadHex.text,
                );
                if (service.isEmpty || characteristic.isEmpty) {
                  setDialogState(
                    () => error = 'Укажите UUID сервиса и характеристики.',
                  );
                  return;
                }
                if (normalizedPayload == null) {
                  setDialogState(
                    () => error =
                        'Payload должен быть hex-байтами: например 01 00 FF.',
                  );
                  return;
                }
                final normalizedTitle = title.text.trim().isEmpty
                    ? 'BLE-команда $characteristic'
                    : title.text.trim();
                Navigator.pop(
                  dialogContext,
                  BleWriteCommand(
                    id: command?.id ?? newId(),
                    title: normalizedTitle,
                    serviceUuid: service,
                    characteristicUuid: characteristic,
                    payloadHex: normalizedPayload,
                    withoutResponse: withoutResponse,
                    runBeforeSync: runBeforeSync,
                    delayMs: _parseInt(
                      delayMs.text,
                      command?.delayMs ?? 250,
                    ).clamp(0, 10000).toInt(),
                    enabled: enabled,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  } finally {
    title.dispose();
    serviceUuid.dispose();
    characteristicUuid.dispose();
    payloadHex.dispose();
    delayMs.dispose();
  }
}

String? _normalizeBlePayloadHex(String value) {
  final normalized = value
      .replaceAll(RegExp('0x', caseSensitive: false), '')
      .trim();
  if (normalized.isEmpty) {
    return null;
  }
  final tokens = normalized
      .split(RegExp(r'[\s,;:-]+'))
      .where((item) => item.isNotEmpty)
      .toList();
  final bytes = <int>[];
  if (tokens.length > 1) {
    for (final token in tokens) {
      if (token.length > 2 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(token)) {
        return null;
      }
      bytes.add(int.parse(token, radix: 16));
    }
  } else {
    final compact = normalized.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (compact.isEmpty || compact.length.isOdd) {
      return null;
    }
    for (var index = 0; index < compact.length; index += 2) {
      bytes.add(int.parse(compact.substring(index, index + 2), radix: 16));
    }
  }
  return bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

Future<BleCharacteristicMapping?> _editBleMappingDialog(
  BuildContext context, {
  required List<String> services,
  BleCharacteristicMapping? mapping,
}) async {
  final title = TextEditingController(text: mapping?.title ?? '');
  final serviceUuid = TextEditingController(text: mapping?.serviceUuid ?? '');
  final characteristicUuid = TextEditingController(
    text: mapping?.characteristicUuid ?? '',
  );
  final unit = TextEditingController(text: mapping?.unit ?? '');
  final reference = TextEditingController(text: mapping?.reference ?? '');
  final scale = TextEditingController(text: '${mapping?.scale ?? 1}');
  final offset = TextEditingController(text: '${mapping?.offset ?? 0}');
  final serviceOptions = services.toSet().toList()..sort();
  var metric = _bleMetricLabels.containsKey(mapping?.metric)
      ? mapping!.metric
      : 'customLab';
  var parser = _bleParserLabels.containsKey(mapping?.parser)
      ? mapping!.parser
      : 'uint8';
  var enabled = mapping?.enabled ?? true;
  var error = '';

  try {
    return await showDialog<BleCharacteristicMapping>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            mapping == null ? 'Новая BLE-характеристика' : 'BLE-характеристика',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: шаги браслета',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: metric,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Метрика'),
                    items: [
                      for (final item in _bleMetricLabels.entries)
                        DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => metric = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: parser,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Как читать байты',
                    ),
                    items: [
                      for (final item in _bleParserLabels.entries)
                        DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => parser = value);
                      }
                    },
                  ),
                  if (serviceOptions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LocalizedDropdownButtonFormField<String>(
                      initialValue: serviceOptions.contains(serviceUuid.text)
                          ? serviceUuid.text
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Найденный сервис',
                      ),
                      items: [
                        for (final item in serviceOptions.take(40))
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => serviceUuid.text = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: serviceUuid,
                    decoration: const InputDecoration(
                      labelText: 'UUID сервиса',
                      hintText: '180d или 0000180d-0000-1000-8000-00805f9b34fb',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedTextField(
                    controller: characteristicUuid,
                    decoration: const InputDecoration(
                      labelText: 'UUID характеристики',
                      hintText: '2a37 или полный 128-битный UUID',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: scale,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Множитель',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedTextField(
                          controller: offset,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Смещение',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: unit,
                          decoration: InputDecoration(
                            labelText: 'Единица',
                            hintText: _defaultBleMetricUnit(metric),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedTextField(
                          controller: reference,
                          decoration: const InputDecoration(
                            labelText: 'Референс',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: const Text('Включить при синхронизации'),
                    onChanged: (value) {
                      setDialogState(() => enabled = value);
                    },
                  ),
                  if (error.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
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
                final service = serviceUuid.text.trim();
                final characteristic = characteristicUuid.text.trim();
                if (service.isEmpty || characteristic.isEmpty) {
                  setDialogState(
                    () => error = 'Укажите UUID сервиса и характеристики.',
                  );
                  return;
                }
                final normalizedTitle = title.text.trim().isEmpty
                    ? _bleMetricLabel(metric)
                    : title.text.trim();
                Navigator.pop(
                  dialogContext,
                  BleCharacteristicMapping(
                    id: mapping?.id ?? newId(),
                    title: normalizedTitle,
                    serviceUuid: service,
                    characteristicUuid: characteristic,
                    metric: metric,
                    parser: parser,
                    unit: unit.text.trim(),
                    reference: reference.text.trim(),
                    scale: _parseDouble(scale.text, mapping?.scale ?? 1),
                    offset: _parseDouble(offset.text, mapping?.offset ?? 0),
                    enabled: enabled,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  } finally {
    title.dispose();
    serviceUuid.dispose();
    characteristicUuid.dispose();
    unit.dispose();
    reference.dispose();
    scale.dispose();
    offset.dispose();
  }
}

List<String> _featuresWithBleMappings(
  List<String> base,
  List<BleCharacteristicMapping> mappings, [
  List<BleWriteCommand> commands = const [],
]) {
  final customLabels = _bleMetricLabels.values.toSet();
  final features = base
      .where((item) => !customLabels.contains(item) && item != 'BLE-команды')
      .toSet();
  for (final mapping in mappings.where((item) => item.enabled)) {
    features.add(_bleMetricLabel(mapping.metric));
  }
  if (commands.any((item) => item.enabled)) {
    features.add('BLE-команды');
  }
  return features.toList()..sort();
}

const _bleMetricLabels = <String, String>{
  'heartRate': 'Пульс',
  'steps': 'Шаги',
  'calories': 'Калории',
  'workoutMinutes': 'Минуты активности',
  'sleepHours': 'Сон',
  'waterLiters': 'Вода',
  'weightKg': 'Вес',
  'glucoseMmolL': 'Глюкоза',
  'spo2Percent': 'SpO2',
  'bodyTemperature': 'Температура тела',
  'bloodPressureSystolic': 'Давление верхнее',
  'bloodPressureDiastolic': 'Давление нижнее',
  'battery': 'Батарея',
  'customLab': 'Пользовательский показатель',
};

const _bleParserLabels = <String, String>{
  'uint8': 'UInt8, первый байт',
  'int8': 'Int8, первый байт',
  'uint16le': 'UInt16 little-endian',
  'uint16be': 'UInt16 big-endian',
  'int16le': 'Int16 little-endian',
  'int16be': 'Int16 big-endian',
  'uint32le': 'UInt32 little-endian',
  'uint32be': 'UInt32 big-endian',
  'int32le': 'Int32 little-endian',
  'int32be': 'Int32 big-endian',
  'float32le': 'Float32 little-endian',
  'float32be': 'Float32 big-endian',
  'sfloat': 'Bluetooth SFLOAT',
  'utf8-number': 'UTF-8 число',
  'utf8': 'UTF-8 текст',
  'hex': 'Hex как число',
};

String _bleMetricLabel(String metric) => _bleMetricLabels[metric] ?? metric;

String _bleParserLabel(String parser) => _bleParserLabels[parser] ?? parser;

DailyMetrics? _applyBleMappedMetric(
  DailyMetrics metrics,
  HealthBleMappedMeasurement measurement,
) {
  final value = measurement.numericValue;
  if (value == null) {
    return null;
  }
  return switch (measurement.mapping.metric) {
    'steps' => metrics.copyWith(steps: _boundedInt(value, 0, 200000)),
    'calories' => metrics.copyWith(calories: _boundedInt(value, 0, 20000)),
    'workoutMinutes' => metrics.copyWith(
      workoutMinutes: _boundedInt(value, 0, 1440),
    ),
    'sleepHours' => metrics.copyWith(sleepHours: value.clamp(0, 24).toDouble()),
    'waterLiters' => metrics.copyWith(
      waterLiters: value.clamp(0, 20).toDouble(),
    ),
    'weightKg' => metrics.copyWith(weightKg: value.clamp(0, 500).toDouble()),
    _ => null,
  };
}

int _boundedInt(double value, int min, int max) {
  return value.round().clamp(min, max).toInt();
}

int? _mappedBatteryPercent(List<HealthBleMappedMeasurement> measurements) {
  for (final measurement in measurements) {
    if (measurement.mapping.metric == 'battery' &&
        measurement.numericValue != null) {
      return _boundedInt(measurement.numericValue!, 0, 100);
    }
  }
  return null;
}

List<LabResult> _bleLabResults(
  HealthBleSyncResult result,
  String deviceTitle,
  String date,
) {
  return [
    if (result.heartRate != null)
      LabResult(
        id: newId(),
        marker: 'Пульс',
        value: '${result.heartRate}',
        unit: 'уд/мин',
        reference: 'индивидуально',
        date: date,
        needsAttention: false,
        notes: 'Получено по Bluetooth LE от $deviceTitle.',
      ),
    if (result.glucoseMmolL != null)
      LabResult(
        id: newId(),
        marker: 'Глюкоза',
        value: result.glucoseMmolL!.toStringAsFixed(1),
        unit: 'ммоль/л',
        reference: 'см. назначение врача',
        date: date,
        needsAttention: true,
        notes:
            'Получено по Bluetooth LE от $deviceTitle; проверьте единицы датчика.',
      ),
    if (result.spo2Percent != null)
      LabResult(
        id: newId(),
        marker: 'SpO2',
        value: '${result.spo2Percent}',
        unit: '%',
        reference: 'обычно 95-100%',
        date: date,
        needsAttention: result.spo2Percent! < 95,
        notes: 'Получено по Bluetooth LE от $deviceTitle.',
      ),
    if (result.bodyTemperatureC != null)
      LabResult(
        id: newId(),
        marker: 'Температура тела',
        value: result.bodyTemperatureC!.toStringAsFixed(1),
        unit: '°C',
        reference: 'индивидуально',
        date: date,
        needsAttention:
            result.bodyTemperatureC! >= 37.5 || result.bodyTemperatureC! < 35,
        notes: 'Получено по Bluetooth LE от $deviceTitle.',
      ),
    if (result.bloodPressureSystolic != null &&
        result.bloodPressureDiastolic != null) ...[
      LabResult(
        id: newId(),
        marker: 'Давление верхнее',
        value: '${result.bloodPressureSystolic}',
        unit: 'мм рт. ст.',
        reference: 'индивидуально',
        date: date,
        needsAttention:
            result.bloodPressureSystolic! >= 140 ||
            result.bloodPressureSystolic! < 90,
        notes: 'Получено по Bluetooth LE от $deviceTitle.',
      ),
      LabResult(
        id: newId(),
        marker: 'Давление нижнее',
        value: '${result.bloodPressureDiastolic}',
        unit: 'мм рт. ст.',
        reference: 'индивидуально',
        date: date,
        needsAttention:
            result.bloodPressureDiastolic! >= 90 ||
            result.bloodPressureDiastolic! < 50,
        notes: 'Получено по Bluetooth LE от $deviceTitle.',
      ),
    ],
    ...result.mappedMeasurements
        .where(_isBleMappedLabMeasurement)
        .map((item) => _bleMappedLabResult(item, deviceTitle, date)),
  ];
}

bool _isBleMappedLabMeasurement(HealthBleMappedMeasurement measurement) {
  return switch (measurement.mapping.metric) {
    'heartRate' ||
    'glucoseMmolL' ||
    'spo2Percent' ||
    'bodyTemperature' ||
    'bloodPressureSystolic' ||
    'bloodPressureDiastolic' ||
    'customLab' => measurement.hasValue,
    _ => false,
  };
}

LabResult _bleMappedLabResult(
  HealthBleMappedMeasurement measurement,
  String deviceTitle,
  String date,
) {
  final metric = measurement.mapping.metric;
  final marker = measurement.mapping.title.isEmpty
      ? _bleMetricLabel(metric)
      : measurement.mapping.title;
  final numeric = measurement.numericValue;
  final value = numeric == null
      ? measurement.displayValue
      : (numeric == numeric.roundToDouble()
            ? numeric.toStringAsFixed(0)
            : numeric.toStringAsFixed(2));
  final unit = measurement.mapping.unit.isNotEmpty
      ? measurement.mapping.unit
      : _defaultBleMetricUnit(metric);
  final reference = measurement.mapping.reference.isNotEmpty
      ? measurement.mapping.reference
      : _defaultBleMetricReference(metric);
  return LabResult(
    id: newId(),
    marker: marker,
    value: value,
    unit: unit,
    reference: reference,
    date: date,
    needsAttention: _bleMappedNeedsAttention(measurement),
    notes:
        'Получено по Bluetooth LE от $deviceTitle через пользовательский профиль. Raw: ${measurement.rawHex}.',
  );
}

bool _bleMappedNeedsAttention(HealthBleMappedMeasurement measurement) {
  final value = measurement.numericValue;
  if (value == null) {
    return false;
  }
  return switch (measurement.mapping.metric) {
    'spo2Percent' => value < 95,
    'bodyTemperature' => value >= 37.5 || value < 35,
    'glucoseMmolL' => true,
    'bloodPressureSystolic' => value >= 140 || value < 90,
    'bloodPressureDiastolic' => value >= 90 || value < 50,
    _ => false,
  };
}

String _defaultBleMetricUnit(String metric) {
  return switch (metric) {
    'heartRate' => 'уд/мин',
    'glucoseMmolL' => 'ммоль/л',
    'spo2Percent' => '%',
    'bodyTemperature' => '°C',
    'bloodPressureSystolic' || 'bloodPressureDiastolic' => 'мм рт. ст.',
    'steps' => 'шагов',
    'calories' => 'ккал',
    'workoutMinutes' => 'мин',
    'sleepHours' => 'ч',
    'waterLiters' => 'л',
    'weightKg' => 'кг',
    'battery' => '%',
    _ => '',
  };
}

String _defaultBleMetricReference(String metric) {
  return switch (metric) {
    'spo2Percent' => 'обычно 95-100%',
    'glucoseMmolL' => 'см. назначение врача',
    'bodyTemperature' => 'индивидуально',
    'bloodPressureSystolic' || 'bloodPressureDiastolic' => 'индивидуально',
    _ => 'индивидуально',
  };
}
