import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'model.dart';

class HealthBleDevice {
  const HealthBleDevice({
    required this.deviceId,
    required this.name,
    required this.rssi,
    required this.services,
    required this.isSystemDevice,
  });

  final String deviceId;
  final String name;
  final int? rssi;
  final List<String> services;
  final bool isSystemDevice;

  DeviceConnection toConnection({
    List<String> discoveredServices = const [],
    String status = 'available',
  }) {
    final serviceList = discoveredServices.isNotEmpty
        ? discoveredServices
        : services;
    return DeviceConnection(
      id: deviceId,
      deviceId: deviceId,
      title: name.isEmpty ? 'BLE-устройство $deviceId' : name,
      type: 'Bluetooth LE',
      enabled: status == 'connected',
      lastSync: status == 'connected'
          ? 'только что'
          : 'ещё не синхронизировано',
      permissions: _permissionsForServices(serviceList).join(', '),
      protocol: 'BLE',
      services: serviceList,
      features: _featuresForServices(serviceList),
      status: status,
      rssi: rssi,
      vendor: _guessVendor(name),
      model: name,
    );
  }
}

class HealthBleSyncResult {
  const HealthBleSyncResult({
    this.heartRate,
    this.batteryPercent,
    this.weightKg,
    this.glucoseMmolL,
    this.spo2Percent,
    this.bodyTemperatureC,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.rssi,
    this.mappedMeasurements = const [],
    this.readServices = const [],
    this.errors = const [],
  });

  final int? heartRate;
  final int? batteryPercent;
  final double? weightKg;
  final double? glucoseMmolL;
  final int? spo2Percent;
  final double? bodyTemperatureC;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? rssi;
  final List<HealthBleMappedMeasurement> mappedMeasurements;
  final List<String> readServices;
  final List<String> errors;

  bool get hasMeasurements =>
      heartRate != null ||
      batteryPercent != null ||
      weightKg != null ||
      glucoseMmolL != null ||
      spo2Percent != null ||
      bodyTemperatureC != null ||
      bloodPressureSystolic != null ||
      bloodPressureDiastolic != null ||
      rssi != null ||
      mappedMeasurements.isNotEmpty;

  String get summary {
    final parts = [
      if (heartRate != null) 'пульс $heartRate',
      if (batteryPercent != null) 'батарея $batteryPercent%',
      if (weightKg != null) 'вес ${weightKg!.toStringAsFixed(1)} кг',
      if (glucoseMmolL != null)
        'глюкоза ${glucoseMmolL!.toStringAsFixed(1)} ммоль/л',
      if (spo2Percent != null) 'SpO2 $spo2Percent%',
      if (bodyTemperatureC != null)
        'температура ${bodyTemperatureC!.toStringAsFixed(1)} °C',
      if (bloodPressureSystolic != null && bloodPressureDiastolic != null)
        'АД $bloodPressureSystolic/$bloodPressureDiastolic',
      if (rssi != null) 'RSSI $rssi',
      ...mappedMeasurements.take(4).map((item) => item.summary),
    ];
    if (parts.isEmpty) {
      return errors.isEmpty
          ? 'измерения не найдены'
          : 'измерения не прочитаны: ${errors.join('; ')}';
    }
    return parts.join(' · ');
  }
}

class HealthBleMappedMeasurement {
  const HealthBleMappedMeasurement({
    required this.mapping,
    required this.rawHex,
    this.numericValue,
    this.textValue = '',
  });

  final BleCharacteristicMapping mapping;
  final double? numericValue;
  final String textValue;
  final String rawHex;

  bool get hasValue => numericValue != null || textValue.isNotEmpty;

  String get displayValue {
    if (numericValue != null) {
      final value = numericValue!;
      final formatted = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
      return mapping.unit.isEmpty ? formatted : '$formatted ${mapping.unit}';
    }
    return textValue.isEmpty ? rawHex : textValue;
  }

  String get summary => '${mapping.title}: $displayValue';
}

class HealthBleService {
  HealthBleService() {
    _scanSubscription = UniversalBle.scanStream.listen(_handleScanResult);
  }

  final _devices = <String, HealthBleDevice>{};
  final _controller = StreamController<List<HealthBleDevice>>.broadcast();
  StreamSubscription<BleDevice>? _scanSubscription;

  Stream<List<HealthBleDevice>> get devicesStream => _controller.stream;

  List<HealthBleDevice> get currentDevices => _sortedDevices();

  Future<String> availabilityLabel() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return state.name;
  }

  Future<void> startScan() async {
    await UniversalBle.requestPermissions(withAndroidFineLocation: true);
    final state = await UniversalBle.getBluetoothAvailabilityState();
    if (state != AvailabilityState.poweredOn) {
      throw StateError('Bluetooth недоступен: ${state.name}');
    }
    _devices.clear();
    _emit();
    final systemDevices = await UniversalBle.getSystemDevices();
    for (final device in systemDevices) {
      _handleScanResult(device);
    }
    await UniversalBle.startScan();
  }

  Future<void> stopScan() async {
    if (await UniversalBle.isScanning()) {
      await UniversalBle.stopScan();
    }
  }

  Future<DeviceConnection> connect(HealthBleDevice device) async {
    await stopScan();
    await UniversalBle.connect(device.deviceId);
    final services = await UniversalBle.discoverServices(
      device.deviceId,
      withDescriptors: true,
    );
    final serviceIds = services.map((item) => item.uuid).toList();
    int? rssi;
    try {
      rssi = await UniversalBle.readRssi(device.deviceId);
    } catch (_) {
      rssi = device.rssi;
    }
    return HealthBleDevice(
      deviceId: device.deviceId,
      name: device.name,
      rssi: rssi,
      services: serviceIds,
      isSystemDevice: device.isSystemDevice,
    ).toConnection(discoveredServices: serviceIds, status: 'connected');
  }

  Future<HealthBleSyncResult> sync(DeviceConnection device) async {
    if (device.deviceId.isEmpty) {
      throw StateError('У устройства нет BLE deviceId');
    }
    final errors = <String>[];
    final services = await UniversalBle.discoverServices(
      device.deviceId,
      withDescriptors: true,
    );
    final serviceIds = services.map((item) => item.uuid).toList();

    int? heartRate;
    int? batteryPercent;
    double? weightKg;
    double? glucoseMmolL;
    int? spo2Percent;
    double? bodyTemperatureC;
    int? bloodPressureSystolic;
    int? bloodPressureDiastolic;
    int? rssi;
    final mappedMeasurements = <HealthBleMappedMeasurement>[];

    Future<Uint8List?> readCharacteristic(
      String service,
      String characteristic,
      String label, {
      bool recordError = true,
    }) async {
      final endpoint = _findCharacteristic(services, service, characteristic);
      if (endpoint == null) {
        return null;
      }
      try {
        return await UniversalBle.read(
          device.deviceId,
          endpoint.serviceUuid,
          endpoint.characteristicUuid,
          timeout: const Duration(seconds: 8),
        );
      } catch (error) {
        if (recordError) {
          errors.add('$label: $error');
        }
        return null;
      }
    }

    Future<Uint8List?> readMeasurement(
      String service,
      String characteristic,
      String label,
    ) async {
      final bytes = await readCharacteristic(
        service,
        characteristic,
        label,
        recordError: false,
      );
      if (bytes != null) {
        return bytes;
      }
      final endpoint = _findCharacteristic(services, service, characteristic);
      if (endpoint == null) {
        return null;
      }
      try {
        return await _firstNotifiedValue(
          device.deviceId,
          endpoint.serviceUuid,
          endpoint.characteristicUuid,
        );
      } catch (error) {
        errors.add('$label: read/notify недоступны: $error');
        return null;
      }
    }

    for (final command in device.bleCommands.where(
      (item) => item.enabled && item.runBeforeSync,
    )) {
      try {
        await _writeBleCommand(device.deviceId, services, command);
      } catch (error) {
        errors.add('${_commandTitle(command)}: команда не выполнена: $error');
      }
    }

    final heartRateBytes = await readMeasurement(
      _heartRateService,
      _heartRateMeasurement,
      'пульс',
    );
    if (heartRateBytes != null) {
      heartRate = _parseHeartRate(heartRateBytes);
    }

    final batteryBytes = await readCharacteristic(
      _batteryService,
      _batteryLevel,
      'батарея',
    );
    if (batteryBytes != null && batteryBytes.isNotEmpty) {
      batteryPercent = batteryBytes.first.clamp(0, 100);
    }

    final weightBytes = await readMeasurement(
      _weightScaleService,
      _weightMeasurement,
      'вес',
    );
    if (weightBytes != null) {
      weightKg = _parseWeightKg(weightBytes);
    }

    final glucoseBytes = await readMeasurement(
      _glucoseService,
      _glucoseMeasurement,
      'глюкоза',
    );
    if (glucoseBytes != null) {
      glucoseMmolL = _parseGlucoseMmolL(glucoseBytes);
    }

    final spo2Bytes = await readMeasurement(
      _pulseOximeterService,
      _pulseOximeterSpotCheck,
      'SpO2',
    );
    if (spo2Bytes != null) {
      spo2Percent = _parseSpo2(spo2Bytes);
    }

    final temperatureBytes = await readMeasurement(
      _healthThermometerService,
      _temperatureMeasurement,
      'температура',
    );
    if (temperatureBytes != null) {
      bodyTemperatureC = _parseTemperatureC(temperatureBytes);
    }

    final pressureBytes = await readMeasurement(
      _bloodPressureService,
      _bloodPressureMeasurement,
      'давление',
    );
    if (pressureBytes != null) {
      final pressure = _parseBloodPressure(pressureBytes);
      bloodPressureSystolic = pressure?.systolic;
      bloodPressureDiastolic = pressure?.diastolic;
    }

    for (final mapping in device.bleMappings.where((item) => item.enabled)) {
      if (mapping.serviceUuid.isEmpty || mapping.characteristicUuid.isEmpty) {
        errors.add(
          '${mapping.title}: UUID сервиса или характеристики не указан',
        );
        continue;
      }
      final bytes = await readCharacteristic(
        mapping.serviceUuid,
        mapping.characteristicUuid,
        mapping.title,
      );
      if (bytes == null) {
        errors.add('${mapping.title}: характеристика не найдена');
        continue;
      }
      final measurement = _parseMappedMeasurement(mapping, bytes);
      if (measurement.hasValue) {
        mappedMeasurements.add(measurement);
      } else {
        errors.add(
          '${mapping.title}: не удалось разобрать ${measurement.rawHex}',
        );
      }
    }

    try {
      rssi = await UniversalBle.readRssi(device.deviceId);
    } catch (error) {
      errors.add('RSSI: $error');
    }

    return HealthBleSyncResult(
      heartRate: heartRate,
      batteryPercent: batteryPercent,
      weightKg: weightKg,
      glucoseMmolL: glucoseMmolL,
      spo2Percent: spo2Percent,
      bodyTemperatureC: bodyTemperatureC,
      bloodPressureSystolic: bloodPressureSystolic,
      bloodPressureDiastolic: bloodPressureDiastolic,
      rssi: rssi,
      mappedMeasurements: mappedMeasurements,
      readServices: serviceIds,
      errors: errors,
    );
  }

  Future<void> writeCommand(
    DeviceConnection device,
    BleWriteCommand command,
  ) async {
    if (device.deviceId.isEmpty) {
      throw StateError('У устройства нет BLE deviceId');
    }
    final services = await UniversalBle.discoverServices(
      device.deviceId,
      withDescriptors: true,
    );
    await _writeBleCommand(device.deviceId, services, command);
  }

  Future<void> disconnect(DeviceConnection device) async {
    if (device.deviceId.isNotEmpty) {
      await UniversalBle.disconnect(device.deviceId);
    }
  }

  void dispose() {
    unawaited(_scanSubscription?.cancel());
    unawaited(_controller.close());
  }

  void _handleScanResult(BleDevice device) {
    _devices[device.deviceId] = HealthBleDevice(
      deviceId: device.deviceId,
      name: device.name ?? device.rawName ?? '',
      rssi: device.rssi,
      services: device.services,
      isSystemDevice: device.isSystemDevice ?? false,
    );
    _emit();
  }

  void _emit() => _controller.add(_sortedDevices());

  List<HealthBleDevice> _sortedDevices() {
    final list = _devices.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return list;
  }
}

const _heartRateService = '180d';
const _heartRateMeasurement = '2a37';
const _batteryService = '180f';
const _batteryLevel = '2a19';
const _weightScaleService = '181d';
const _weightMeasurement = '2a9d';
const _glucoseService = '1808';
const _glucoseMeasurement = '2a18';
const _pulseOximeterService = '1822';
const _pulseOximeterSpotCheck = '2a5e';
const _healthThermometerService = '1809';
const _temperatureMeasurement = '2a1c';
const _bloodPressureService = '1810';
const _bloodPressureMeasurement = '2a35';

Future<void> _writeBleCommand(
  String deviceId,
  List<BleService> services,
  BleWriteCommand command,
) async {
  if (command.serviceUuid.isEmpty || command.characteristicUuid.isEmpty) {
    throw StateError('UUID сервиса или характеристики не указан');
  }
  final endpoint = _findCharacteristic(
    services,
    command.serviceUuid,
    command.characteristicUuid,
  );
  if (endpoint == null) {
    throw StateError('характеристика не найдена');
  }
  final payload = _decodeHexPayload(command.payloadHex);
  await UniversalBle.write(
    deviceId,
    endpoint.serviceUuid,
    endpoint.characteristicUuid,
    payload,
    withoutResponse: command.withoutResponse,
  );
  final delayMs = command.delayMs.clamp(0, 10000).toInt();
  if (delayMs > 0) {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }
}

Uint8List _decodeHexPayload(String value) {
  final normalized = value
      .replaceAll(RegExp('0x', caseSensitive: false), '')
      .trim();
  if (normalized.isEmpty) {
    throw const FormatException('payload пуст');
  }
  final tokens = normalized
      .split(RegExp(r'[\s,;:-]+'))
      .where((item) => item.isNotEmpty)
      .toList();
  final bytes = <int>[];
  if (tokens.length > 1) {
    for (final token in tokens) {
      if (token.length > 2 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(token)) {
        throw FormatException('некорректный hex-байт "$token"');
      }
      bytes.add(int.parse(token, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  final compact = normalized.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (compact.isEmpty || compact.length.isOdd) {
    throw const FormatException('hex должен содержать пары символов');
  }
  for (var index = 0; index < compact.length; index += 2) {
    bytes.add(int.parse(compact.substring(index, index + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

String _commandTitle(BleWriteCommand command) {
  return command.title.trim().isEmpty ? command.payloadHex : command.title;
}

class _BleEndpoint {
  const _BleEndpoint(this.serviceUuid, this.characteristicUuid);

  final String serviceUuid;
  final String characteristicUuid;
}

_BleEndpoint? _findCharacteristic(
  List<BleService> services,
  String serviceUuid,
  String characteristicUuid,
) {
  final serviceToken = serviceUuid.toLowerCase();
  final characteristicToken = characteristicUuid.toLowerCase();
  for (final service in services) {
    if (!service.uuid.toLowerCase().contains(serviceToken)) {
      continue;
    }
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid.toLowerCase().contains(characteristicToken)) {
        return _BleEndpoint(service.uuid, characteristic.uuid);
      }
    }
  }
  return null;
}

Future<Uint8List?> _firstNotifiedValue(
  String deviceId,
  String serviceUuid,
  String characteristicUuid,
) async {
  Future<Uint8List?> subscribeAndWait(Future<void> Function() subscribe) async {
    final stream = UniversalBle.characteristicValueStream(
      deviceId,
      characteristicUuid,
    );
    try {
      final future = stream.first.timeout(const Duration(seconds: 4));
      await subscribe();
      return await future;
    } finally {
      try {
        await UniversalBle.unsubscribe(
          deviceId,
          serviceUuid,
          characteristicUuid,
          timeout: const Duration(seconds: 4),
        );
      } catch (_) {
        // Some platforms auto-stop notifications when the subscription fails.
      }
    }
  }

  try {
    return await subscribeAndWait(
      () => UniversalBle.subscribeNotifications(
        deviceId,
        serviceUuid,
        characteristicUuid,
        timeout: const Duration(seconds: 4),
      ),
    );
  } catch (_) {
    return subscribeAndWait(
      () => UniversalBle.subscribeIndications(
        deviceId,
        serviceUuid,
        characteristicUuid,
        timeout: const Duration(seconds: 4),
      ),
    );
  }
}

int? _parseHeartRate(Uint8List bytes) {
  if (bytes.length < 2) {
    return null;
  }
  final flags = bytes[0];
  final sixteenBit = (flags & 0x01) == 0x01;
  if (sixteenBit && bytes.length >= 3) {
    return ByteData.sublistView(bytes, 1, 3).getUint16(0, Endian.little);
  }
  return bytes[1];
}

double? _parseWeightKg(Uint8List bytes) {
  if (bytes.length < 3) {
    return null;
  }
  final flags = bytes[0];
  final raw = ByteData.sublistView(bytes, 1, 3).getUint16(0, Endian.little);
  final imperial = (flags & 0x01) == 0x01;
  final value = raw / 200.0;
  return imperial ? value * 0.45359237 : value;
}

double? _parseGlucoseMmolL(Uint8List bytes) {
  if (bytes.length < 14) {
    return null;
  }
  final flags = bytes[0];
  final hasConcentration = (flags & 0x02) == 0x02;
  if (!hasConcentration) {
    return null;
  }
  final raw = ByteData.sublistView(bytes, 12, 14).getUint16(0, Endian.little);
  final kgPerLiter = _sfloatToDouble(raw);
  if (kgPerLiter <= 0) {
    return null;
  }
  return kgPerLiter * 100000;
}

int? _parseSpo2(Uint8List bytes) {
  if (bytes.length < 3) {
    return null;
  }
  final raw = ByteData.sublistView(bytes, 1, 3).getUint16(0, Endian.little);
  final value = _sfloatToDouble(raw).round();
  return value <= 0 ? null : value.clamp(0, 100);
}

double? _parseTemperatureC(Uint8List bytes) {
  if (bytes.length < 5) {
    return null;
  }
  final flags = bytes[0];
  final fahrenheit = (flags & 0x01) == 0x01;
  final value = _floatToDouble(ByteData.sublistView(bytes, 1, 5));
  if (value <= 0) {
    return null;
  }
  return fahrenheit ? (value - 32) * 5 / 9 : value;
}

_BloodPressure? _parseBloodPressure(Uint8List bytes) {
  if (bytes.length < 7) {
    return null;
  }
  final flags = bytes[0];
  final kpa = (flags & 0x01) == 0x01;
  final systolic = _sfloatToDouble(
    ByteData.sublistView(bytes, 1, 3).getUint16(0, Endian.little),
  );
  final diastolic = _sfloatToDouble(
    ByteData.sublistView(bytes, 3, 5).getUint16(0, Endian.little),
  );
  if (systolic <= 0 || diastolic <= 0) {
    return null;
  }
  final multiplier = kpa ? 7.50062 : 1.0;
  return _BloodPressure(
    (systolic * multiplier).round(),
    (diastolic * multiplier).round(),
  );
}

HealthBleMappedMeasurement _parseMappedMeasurement(
  BleCharacteristicMapping mapping,
  Uint8List bytes,
) {
  final rawHex = _bytesToHex(bytes);
  if (mapping.parser == 'utf8' || mapping.parser == 'utf8-number') {
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (mapping.parser == 'utf8-number') {
      final numeric = double.tryParse(text.replaceAll(',', '.'));
      return HealthBleMappedMeasurement(
        mapping: mapping,
        rawHex: rawHex,
        numericValue: _scaledValue(mapping, numeric),
        textValue: text,
      );
    }
    return HealthBleMappedMeasurement(
      mapping: mapping,
      rawHex: rawHex,
      textValue: text,
    );
  }

  final numeric = _parseMappedNumber(mapping.parser, bytes);
  return HealthBleMappedMeasurement(
    mapping: mapping,
    rawHex: rawHex,
    numericValue: _scaledValue(mapping, numeric),
  );
}

double? _scaledValue(BleCharacteristicMapping mapping, double? value) {
  if (value == null) {
    return null;
  }
  return (value * mapping.scale) + mapping.offset;
}

double? _parseMappedNumber(String parser, Uint8List bytes) {
  if (bytes.isEmpty) {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  return switch (parser) {
    'uint8' => data.getUint8(0).toDouble(),
    'int8' => data.getInt8(0).toDouble(),
    'uint16le' when bytes.length >= 2 =>
      data.getUint16(0, Endian.little).toDouble(),
    'uint16be' when bytes.length >= 2 =>
      data.getUint16(0, Endian.big).toDouble(),
    'int16le' when bytes.length >= 2 =>
      data.getInt16(0, Endian.little).toDouble(),
    'int16be' when bytes.length >= 2 => data.getInt16(0, Endian.big).toDouble(),
    'uint32le' when bytes.length >= 4 =>
      data.getUint32(0, Endian.little).toDouble(),
    'uint32be' when bytes.length >= 4 =>
      data.getUint32(0, Endian.big).toDouble(),
    'int32le' when bytes.length >= 4 =>
      data.getInt32(0, Endian.little).toDouble(),
    'int32be' when bytes.length >= 4 => data.getInt32(0, Endian.big).toDouble(),
    'float32le' when bytes.length >= 4 => data.getFloat32(0, Endian.little),
    'float32be' when bytes.length >= 4 => data.getFloat32(0, Endian.big),
    'sfloat' when bytes.length >= 2 => _sfloatToDouble(
      data.getUint16(0, Endian.little),
    ),
    'hex' => int.tryParse(_bytesToHex(bytes), radix: 16)?.toDouble(),
    _ => null,
  };
}

String _bytesToHex(Uint8List bytes) {
  return bytes.map((item) => item.toRadixString(16).padLeft(2, '0')).join();
}

double _sfloatToDouble(int raw) {
  var mantissa = raw & 0x0fff;
  var exponent = raw >> 12;
  if ((mantissa & 0x0800) != 0) {
    mantissa = -((0x0fff + 1) - mantissa);
  }
  if ((exponent & 0x0008) != 0) {
    exponent = -((0x000f + 1) - exponent);
  }
  return mantissa * _pow10(exponent);
}

double _floatToDouble(ByteData data) {
  var mantissa =
      data.getUint8(0) | (data.getUint8(1) << 8) | (data.getUint8(2) << 16);
  if ((mantissa & 0x800000) != 0) {
    mantissa = -((0xffffff + 1) - mantissa);
  }
  var exponent = data.getInt8(3);
  return mantissa * _pow10(exponent);
}

class _BloodPressure {
  const _BloodPressure(this.systolic, this.diastolic);

  final int systolic;
  final int diastolic;
}

double _pow10(int exponent) {
  var value = 1.0;
  if (exponent >= 0) {
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
  } else {
    for (var i = 0; i < -exponent; i++) {
      value /= 10;
    }
  }
  return value;
}

List<String> _permissionsForServices(List<String> services) {
  final features = _featuresForServices(services);
  if (features.isEmpty) {
    return ['ручное подтверждение данных'];
  }
  return features;
}

List<String> _featuresForServices(List<String> services) {
  final normalized = services.map((item) => item.toLowerCase()).toSet();
  final result = <String>[];
  if (normalized.any((item) => item.contains('180d'))) {
    result.add('пульс');
  }
  if (normalized.any((item) => item.contains('180f'))) {
    result.add('заряд батареи');
  }
  if (normalized.any((item) => item.contains('1814'))) {
    result.add('скорость и каденс');
  }
  if (normalized.any((item) => item.contains('1816'))) {
    result.add('велодатчик');
  }
  if (normalized.any((item) => item.contains('1808'))) {
    result.add('глюкоза');
  }
  if (normalized.any((item) => item.contains('1809'))) {
    result.add('температура тела');
  }
  if (normalized.any((item) => item.contains('1810'))) {
    result.add('давление');
  }
  if (normalized.any((item) => item.contains('1819'))) {
    result.add('здоровье окружения');
  }
  if (normalized.any((item) => item.contains('181d'))) {
    result.add('вес');
  }
  if (normalized.any((item) => item.contains('181e'))) {
    result.add('велотренажёр');
  }
  if (normalized.any((item) => item.contains('1822'))) {
    result.add('пульсоксиметрия');
  }
  if (result.isEmpty && services.isNotEmpty) {
    result.add('пользовательские BLE-сервисы');
  }
  return result;
}

String _guessVendor(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('mi') || lower.contains('xiaomi')) {
    return 'Xiaomi';
  }
  if (lower.contains('fitbit')) {
    return 'Fitbit';
  }
  if (lower.contains('garmin')) {
    return 'Garmin';
  }
  if (lower.contains('oura')) {
    return 'Oura';
  }
  if (lower.contains('whoop')) {
    return 'WHOOP';
  }
  if (lower.contains('withings')) {
    return 'Withings';
  }
  if (lower.contains('samsung')) {
    return 'Samsung';
  }
  return '';
}
