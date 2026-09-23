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
    this.bodyFatPercent,
    this.muscleMassKg,
    this.speedKmh,
    this.distanceMeters,
    this.cadenceRpm,
    this.powerWatts,
    this.energyKcal,
    this.elapsedSeconds,
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
  final double? bodyFatPercent;
  final double? muscleMassKg;
  final double? speedKmh;
  final double? distanceMeters;
  final double? cadenceRpm;
  final int? powerWatts;
  final int? energyKcal;
  final int? elapsedSeconds;
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
      bodyFatPercent != null ||
      muscleMassKg != null ||
      speedKmh != null ||
      distanceMeters != null ||
      cadenceRpm != null ||
      powerWatts != null ||
      energyKcal != null ||
      elapsedSeconds != null ||
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
      if (bodyFatPercent != null) 'жир ${bodyFatPercent!.toStringAsFixed(1)}%',
      if (muscleMassKg != null) 'мышцы ${muscleMassKg!.toStringAsFixed(1)} кг',
      if (speedKmh != null) 'скорость ${speedKmh!.toStringAsFixed(1)} км/ч',
      if (distanceMeters != null)
        'дистанция ${(distanceMeters! / 1000).toStringAsFixed(2)} км',
      if (cadenceRpm != null) 'каденс ${cadenceRpm!.toStringAsFixed(0)} об/мин',
      if (powerWatts != null) 'мощность $powerWatts Вт',
      if (energyKcal != null) 'энергия $energyKcal ккал',
      if (elapsedSeconds != null) 'время ${(elapsedSeconds! / 60).round()} мин',
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
    double? bodyFatPercent;
    double? muscleMassKg;
    double? speedKmh;
    double? distanceMeters;
    double? cadenceRpm;
    int? powerWatts;
    int? energyKcal;
    int? elapsedSeconds;
    int? rssi;
    final mappedMeasurements = <HealthBleMappedMeasurement>[];

    void includeStandard(HealthBleSyncResult value) {
      heartRate ??= value.heartRate;
      weightKg ??= value.weightKg;
      glucoseMmolL ??= value.glucoseMmolL;
      spo2Percent ??= value.spo2Percent;
      bodyTemperatureC ??= value.bodyTemperatureC;
      bloodPressureSystolic ??= value.bloodPressureSystolic;
      bloodPressureDiastolic ??= value.bloodPressureDiastolic;
      bodyFatPercent ??= value.bodyFatPercent;
      muscleMassKg ??= value.muscleMassKg;
      speedKmh ??= value.speedKmh;
      distanceMeters ??= value.distanceMeters;
      cadenceRpm ??= value.cadenceRpm;
      powerWatts ??= value.powerWatts;
      energyKcal ??= value.energyKcal;
      elapsedSeconds ??= value.elapsedSeconds;
      errors.addAll(value.errors);
    }

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

    final cgmBytes = await readMeasurement(
      _continuousGlucoseService,
      _continuousGlucoseMeasurement,
      'непрерывная глюкоза',
    );
    if (cgmBytes != null) {
      includeStandard(
        HealthBleDecoder.decode(_continuousGlucoseMeasurement, cgmBytes),
      );
    }

    final spo2Bytes = await readMeasurement(
      _pulseOximeterService,
      _pulseOximeterSpotCheck,
      'SpO2',
    );
    if (spo2Bytes != null) {
      spo2Percent = _parseSpo2(spo2Bytes);
    } else {
      final continuousSpo2 = await readMeasurement(
        _pulseOximeterService,
        _pulseOximeterContinuous,
        'непрерывный SpO2',
      );
      if (continuousSpo2 != null) {
        includeStandard(
          HealthBleDecoder.decode(_pulseOximeterContinuous, continuousSpo2),
        );
      }
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

    final bodyCompositionBytes = await readMeasurement(
      _bodyCompositionService,
      _bodyCompositionMeasurement,
      'состав тела',
    );
    if (bodyCompositionBytes != null) {
      includeStandard(
        HealthBleDecoder.decode(
          _bodyCompositionMeasurement,
          bodyCompositionBytes,
        ),
      );
    }

    for (final characteristic in const [
      _treadmillData,
      _indoorBikeData,
      _rowerData,
    ]) {
      final fitnessBytes = await readMeasurement(
        _fitnessMachineService,
        characteristic,
        'данные тренажёра',
      );
      if (fitnessBytes != null) {
        includeStandard(HealthBleDecoder.decode(characteristic, fitnessBytes));
        break;
      }
    }

    final runningBytes = await readMeasurement(
      _runningSpeedCadenceService,
      _runningSpeedCadenceMeasurement,
      'датчик бега',
    );
    if (runningBytes != null) {
      includeStandard(
        HealthBleDecoder.decode(_runningSpeedCadenceMeasurement, runningBytes),
      );
    }

    final cyclingPowerBytes = await readMeasurement(
      _cyclingPowerService,
      _cyclingPowerMeasurement,
      'веломощность',
    );
    if (cyclingPowerBytes != null) {
      includeStandard(
        HealthBleDecoder.decode(_cyclingPowerMeasurement, cyclingPowerBytes),
      );
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
      bodyFatPercent: bodyFatPercent,
      muscleMassKg: muscleMassKg,
      speedKmh: speedKmh,
      distanceMeters: distanceMeters,
      cadenceRpm: cadenceRpm,
      powerWatts: powerWatts,
      energyKcal: energyKcal,
      elapsedSeconds: elapsedSeconds,
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
    if (isProtectedMedicalWrite(device, command)) {
      throw UnsupportedError(
        'Команды для CGM и систем доставки инсулина заблокированы. '
        'MyHealth использует эти устройства только для чтения и журнала.',
      );
    }
    final services = await UniversalBle.discoverServices(
      device.deviceId,
      withDescriptors: true,
    );
    await _writeBleCommand(device.deviceId, services, command);
  }

  static bool isProtectedMedicalWrite(
    DeviceConnection device,
    BleWriteCommand command,
  ) {
    final service = _shortUuid(command.serviceUuid);
    final description =
        '${device.type} ${device.title} ${device.features.join(' ')}'
            .toLowerCase();
    return service == _continuousGlucoseService ||
        service == '183a' ||
        description.contains('инсулин') ||
        description.contains('insulin pump') ||
        description.contains('cgm');
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
const _pulseOximeterContinuous = '2a5f';
const _healthThermometerService = '1809';
const _temperatureMeasurement = '2a1c';
const _bloodPressureService = '1810';
const _bloodPressureMeasurement = '2a35';
const _continuousGlucoseService = '181f';
const _continuousGlucoseMeasurement = '2aa7';
const _bodyCompositionService = '181b';
const _bodyCompositionMeasurement = '2a9c';
const _fitnessMachineService = '1826';
const _treadmillData = '2acd';
const _rowerData = '2ad1';
const _indoorBikeData = '2ad2';
const _runningSpeedCadenceService = '1814';
const _runningSpeedCadenceMeasurement = '2a53';
const _cyclingPowerService = '1818';
const _cyclingPowerMeasurement = '2a63';

/// Decodes Bluetooth SIG adopted health and fitness characteristics.
///
/// Vendor-specific devices can still be handled through user mappings, while
/// this decoder keeps adopted profiles deterministic and unit-tested.
class HealthBleDecoder {
  const HealthBleDecoder._();

  static HealthBleSyncResult decode(
    String characteristicUuid,
    Uint8List bytes,
  ) {
    final uuid = _shortUuid(characteristicUuid);
    try {
      return switch (uuid) {
        _continuousGlucoseMeasurement => _decodeContinuousGlucose(bytes),
        _bodyCompositionMeasurement => _decodeBodyComposition(bytes),
        _treadmillData => _decodeTreadmill(bytes),
        _indoorBikeData => _decodeIndoorBike(bytes),
        _rowerData => _decodeRower(bytes),
        _runningSpeedCadenceMeasurement => _decodeRunning(bytes),
        _cyclingPowerMeasurement => _decodeCyclingPower(bytes),
        _pulseOximeterContinuous => _decodeContinuousSpo2(bytes),
        _ => HealthBleSyncResult(
          errors: ['Неизвестная стандартная характеристика $uuid'],
        ),
      };
    } on FormatException catch (error) {
      return HealthBleSyncResult(errors: ['$uuid: ${error.message}']);
    } on RangeError {
      return HealthBleSyncResult(errors: ['$uuid: пакет короче заявленного']);
    }
  }

  static HealthBleSyncResult _decodeContinuousGlucose(Uint8List bytes) {
    if (bytes.length < 6) {
      throw const FormatException('некорректная CGM-запись');
    }
    double? latest;
    final warnings = <String>[];
    var offset = 0;
    while (offset + 6 <= bytes.length) {
      final size = bytes[offset];
      if (size < 6 || offset + size > bytes.length) {
        throw const FormatException('ошибка размера CGM-записи');
      }
      final mgDl = _sfloatToDouble(
        ByteData.sublistView(
          bytes,
          offset + 2,
          offset + 4,
        ).getUint16(0, Endian.little),
      );
      if (mgDl >= 20 && mgDl <= 600) {
        latest = mgDl / 18.01559;
      } else {
        warnings.add('CGM передал неправдоподобное значение $mgDl мг/дл');
      }
      offset += size;
    }
    return HealthBleSyncResult(glucoseMmolL: latest, errors: warnings);
  }

  static HealthBleSyncResult _decodeBodyComposition(Uint8List bytes) {
    if (bytes.length < 4) {
      throw const FormatException('некорректный пакет состава тела');
    }
    final cursor = _BleCursor(bytes);
    final flags = cursor.u16();
    final imperial = (flags & 0x0001) != 0;
    final bodyFat = cursor.u16() / 10.0;
    if ((flags & 0x0002) != 0) cursor.skip(7); // timestamp
    if ((flags & 0x0004) != 0) cursor.skip(1); // user id
    if ((flags & 0x0008) != 0) cursor.skip(2); // basal metabolism
    if ((flags & 0x0010) != 0) cursor.skip(2); // muscle percentage
    double? muscleMass;
    if ((flags & 0x0020) != 0) {
      final value = cursor.u16() / 100.0;
      muscleMass = imperial ? value * 0.45359237 : value;
    }
    if ((flags & 0x0040) != 0) cursor.skip(2); // fat free mass
    if ((flags & 0x0080) != 0) cursor.skip(2); // soft lean mass
    if ((flags & 0x0100) != 0) cursor.skip(2); // body water mass
    if ((flags & 0x0200) != 0) cursor.skip(2); // impedance
    double? weight;
    if ((flags & 0x0400) != 0) {
      final value = imperial ? cursor.u16() / 100.0 : cursor.u16() / 200.0;
      weight = imperial ? value * 0.45359237 : value;
    }
    return HealthBleSyncResult(
      bodyFatPercent: bodyFat,
      muscleMassKg: muscleMass,
      weightKg: weight,
    );
  }

  static HealthBleSyncResult _decodeIndoorBike(Uint8List bytes) {
    final cursor = _BleCursor(bytes);
    final flags = cursor.u16();
    double? speed;
    double? cadence;
    double? distance;
    int? power;
    int? energy;
    int? heartRate;
    int? elapsed;
    if ((flags & 0x0001) == 0) speed = cursor.u16() / 100.0;
    if ((flags & 0x0002) != 0) cursor.skip(2); // average speed
    if ((flags & 0x0004) != 0) cadence = cursor.u16() / 2.0;
    if ((flags & 0x0008) != 0) cursor.skip(2); // average cadence
    if ((flags & 0x0010) != 0) distance = cursor.u24().toDouble();
    if ((flags & 0x0020) != 0) cursor.skip(2); // resistance
    if ((flags & 0x0040) != 0) power = cursor.i16();
    if ((flags & 0x0080) != 0) cursor.skip(2); // average power
    if ((flags & 0x0100) != 0) {
      energy = cursor.u16();
      cursor.skip(3); // energy/hour and energy/minute
    }
    if ((flags & 0x0200) != 0) heartRate = cursor.u8();
    if ((flags & 0x0400) != 0) cursor.skip(1); // MET
    if ((flags & 0x0800) != 0) elapsed = cursor.u16();
    if ((flags & 0x1000) != 0) cursor.skip(2); // remaining time
    return HealthBleSyncResult(
      heartRate: heartRate,
      speedKmh: speed,
      cadenceRpm: cadence,
      distanceMeters: distance,
      powerWatts: power,
      energyKcal: _validEnergy(energy),
      elapsedSeconds: elapsed,
    );
  }

  static HealthBleSyncResult _decodeTreadmill(Uint8List bytes) {
    final cursor = _BleCursor(bytes);
    final flags = cursor.u16();
    double? speed;
    double? distance;
    int? power;
    int? energy;
    int? heartRate;
    int? elapsed;
    if ((flags & 0x0001) == 0) speed = cursor.u16() / 100.0;
    if ((flags & 0x0002) != 0) cursor.skip(2); // average speed
    if ((flags & 0x0004) != 0) distance = cursor.u24().toDouble();
    if ((flags & 0x0008) != 0) cursor.skip(4); // inclination and ramp
    if ((flags & 0x0010) != 0) cursor.skip(4); // elevation gain
    if ((flags & 0x0020) != 0) cursor.skip(1); // instantaneous pace
    if ((flags & 0x0040) != 0) cursor.skip(1); // average pace
    if ((flags & 0x0080) != 0) {
      energy = cursor.u16();
      cursor.skip(3);
    }
    if ((flags & 0x0100) != 0) heartRate = cursor.u8();
    if ((flags & 0x0200) != 0) cursor.skip(1); // MET
    if ((flags & 0x0400) != 0) elapsed = cursor.u16();
    if ((flags & 0x0800) != 0) cursor.skip(2); // remaining time
    if ((flags & 0x1000) != 0) {
      cursor.skip(2); // force on belt
      power = cursor.i16();
    }
    return HealthBleSyncResult(
      heartRate: heartRate,
      speedKmh: speed,
      distanceMeters: distance,
      powerWatts: power,
      energyKcal: _validEnergy(energy),
      elapsedSeconds: elapsed,
    );
  }

  static HealthBleSyncResult _decodeRower(Uint8List bytes) {
    final cursor = _BleCursor(bytes);
    final flags = cursor.u16();
    double? cadence;
    double? distance;
    int? power;
    int? energy;
    int? heartRate;
    int? elapsed;
    if ((flags & 0x0001) == 0) {
      cadence = cursor.u8() / 2.0;
      cursor.skip(2); // stroke count
    }
    if ((flags & 0x0002) != 0) cursor.skip(1); // average stroke rate
    if ((flags & 0x0004) != 0) distance = cursor.u24().toDouble();
    if ((flags & 0x0008) != 0) cursor.skip(2); // instantaneous pace
    if ((flags & 0x0010) != 0) cursor.skip(2); // average pace
    if ((flags & 0x0020) != 0) power = cursor.i16();
    if ((flags & 0x0040) != 0) cursor.skip(2); // average power
    if ((flags & 0x0080) != 0) cursor.skip(2); // resistance
    if ((flags & 0x0100) != 0) {
      energy = cursor.u16();
      cursor.skip(3);
    }
    if ((flags & 0x0200) != 0) heartRate = cursor.u8();
    if ((flags & 0x0400) != 0) cursor.skip(1); // MET
    if ((flags & 0x0800) != 0) elapsed = cursor.u16();
    if ((flags & 0x1000) != 0) cursor.skip(2); // remaining time
    return HealthBleSyncResult(
      heartRate: heartRate,
      cadenceRpm: cadence,
      distanceMeters: distance,
      powerWatts: power,
      energyKcal: _validEnergy(energy),
      elapsedSeconds: elapsed,
    );
  }

  static HealthBleSyncResult _decodeRunning(Uint8List bytes) {
    final cursor = _BleCursor(bytes);
    final flags = cursor.u8();
    final speed = cursor.u16() / 256.0 * 3.6;
    final cadence = cursor.u8().toDouble();
    if ((flags & 0x01) != 0) cursor.skip(2); // stride length
    final distance = (flags & 0x02) != 0 ? cursor.u32() / 10.0 : null;
    return HealthBleSyncResult(
      speedKmh: speed,
      cadenceRpm: cadence,
      distanceMeters: distance,
    );
  }

  static HealthBleSyncResult _decodeCyclingPower(Uint8List bytes) {
    final cursor = _BleCursor(bytes);
    cursor.skip(2); // flags
    return HealthBleSyncResult(powerWatts: cursor.i16());
  }

  static HealthBleSyncResult _decodeContinuousSpo2(Uint8List bytes) {
    if (bytes.length < 5) {
      throw const FormatException('некорректный пакет SpO2');
    }
    final value = _sfloatToDouble(
      ByteData.sublistView(bytes, 1, 3).getUint16(0, Endian.little),
    ).round();
    final heartRate = _sfloatToDouble(
      ByteData.sublistView(bytes, 3, 5).getUint16(0, Endian.little),
    ).round();
    return HealthBleSyncResult(
      spo2Percent: value.clamp(0, 100),
      heartRate: heartRate > 0 ? heartRate : null,
    );
  }
}

class _BleCursor {
  _BleCursor(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  void require(int count) {
    if (offset + count > bytes.length) {
      throw const FormatException('пакет короче заявленного');
    }
  }

  void skip(int count) {
    require(count);
    offset += count;
  }

  int u8() {
    require(1);
    return bytes[offset++];
  }

  int u16() {
    require(2);
    final value = ByteData.sublistView(
      bytes,
      offset,
      offset + 2,
    ).getUint16(0, Endian.little);
    offset += 2;
    return value;
  }

  int i16() {
    require(2);
    final value = ByteData.sublistView(
      bytes,
      offset,
      offset + 2,
    ).getInt16(0, Endian.little);
    offset += 2;
    return value;
  }

  int u24() {
    require(3);
    final value =
        bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
    offset += 3;
    return value;
  }

  int u32() {
    require(4);
    final value = ByteData.sublistView(
      bytes,
      offset,
      offset + 4,
    ).getUint32(0, Endian.little);
    offset += 4;
    return value;
  }
}

String _shortUuid(String uuid) {
  final normalized = uuid.toLowerCase().replaceAll('-', '');
  final match = RegExp(r'(2[0-9a-f]{3})').firstMatch(normalized);
  return match?.group(1) ?? normalized;
}

int? _validEnergy(int? value) =>
    value == null || value == 0xffff ? null : value;

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
  if (bytes.length < 13) {
    return null;
  }
  final flags = bytes[0];
  final hasConcentration = (flags & 0x02) == 0x02;
  if (!hasConcentration) {
    return null;
  }
  final hasTimeOffset = (flags & 0x01) != 0;
  final concentrationOffset = hasTimeOffset ? 12 : 10;
  if (bytes.length < concentrationOffset + 3) {
    return null;
  }
  final raw = ByteData.sublistView(
    bytes,
    concentrationOffset,
    concentrationOffset + 2,
  ).getUint16(0, Endian.little);
  final concentration = _sfloatToDouble(raw);
  if (concentration <= 0) {
    return null;
  }
  final molPerLiter = (flags & 0x04) != 0;
  return molPerLiter ? concentration * 1000 : concentration * 100000 / 18.01559;
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
  if (normalized.any((item) => item.contains('181f'))) {
    result.add('непрерывный мониторинг глюкозы');
  }
  if (normalized.any((item) => item.contains('1809'))) {
    result.add('температура тела');
  }
  if (normalized.any((item) => item.contains('1810'))) {
    result.add('давление');
  }
  if (normalized.any((item) => item.contains('1818'))) {
    result.add('веломощность');
  }
  if (normalized.any((item) => item.contains('181a'))) {
    result.add('датчики окружающей среды');
  }
  if (normalized.any((item) => item.contains('181b'))) {
    result.add('состав тела');
  }
  if (normalized.any((item) => item.contains('181d'))) {
    result.add('вес');
  }
  if (normalized.any((item) => item.contains('1826'))) {
    result.add('фитнес-тренажёр FTMS');
  }
  if (normalized.any((item) => item.contains('1822'))) {
    result.add('пульсоксиметрия');
  }
  if (normalized.any((item) => item.contains('183a'))) {
    result.add('инсулиновая помпа через стандарт IDS');
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
