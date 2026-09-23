import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/ble_service.dart';
import 'package:my_health/src/model.dart';

void main() {
  group('Bluetooth SIG health profiles', () {
    test('decodes a CGM measurement in mg/dL to mmol/L', () {
      final result = HealthBleDecoder.decode(
        '00002AA7-0000-1000-8000-00805F9B34FB',
        Uint8List.fromList([6, 0, 100, 0, 0, 0]),
      );

      expect(result.glucoseMmolL, closeTo(5.55, 0.02));
      expect(result.errors, isEmpty);
    });

    test('decodes body fat, muscle mass and weight', () {
      final result = HealthBleDecoder.decode(
        '2a9c',
        Uint8List.fromList([
          0x20, 0x04, // muscle mass and weight, SI
          0xe1, 0x00, // 22.5% fat
          0x64, 0x19, // 65.00 kg muscle mass
          0xb0, 0x36, // 70.00 kg weight
        ]),
      );

      expect(result.bodyFatPercent, 22.5);
      expect(result.muscleMassKg, 65);
      expect(result.weightKg, 70);
    });

    test('decodes indoor bike speed, cadence, distance and power', () {
      final result = HealthBleDecoder.decode(
        '2ad2',
        Uint8List.fromList([
          0x54, 0x0b, // cadence, distance, power, energy, HR, elapsed
          0xd2, 0x04, // 12.34 km/h
          0xb4, 0x00, // 90 rpm
          0x88, 0x13, 0x00, // 5000 m
          0xb4, 0x00, // 180 W
          0xfa, 0x00, 0x00, 0x00, 0x00, // 250 kcal
          140,
          0xb0, 0x04, // 1200 s
        ]),
      );

      expect(result.speedKmh, 12.34);
      expect(result.cadenceRpm, 90);
      expect(result.distanceMeters, 5000);
      expect(result.powerWatts, 180);
      expect(result.energyKcal, 250);
      expect(result.heartRate, 140);
      expect(result.elapsedSeconds, 1200);
    });

    test('decodes treadmill workout data', () {
      final result = HealthBleDecoder.decode(
        '2acd',
        Uint8List.fromList([
          0x84, 0x15, // distance, energy, HR, elapsed, force/power
          0xdc, 0x05, // 15.00 km/h
          0xd0, 0x07, 0x00, // 2000 m
          0x78, 0x00, 0x00, 0x00, 0x00, // 120 kcal
          155,
          0x58, 0x02, // 600 s
          0x00, 0x00, // force
          0x2c, 0x01, // 300 W
        ]),
      );

      expect(result.speedKmh, 15);
      expect(result.distanceMeters, 2000);
      expect(result.energyKcal, 120);
      expect(result.heartRate, 155);
      expect(result.elapsedSeconds, 600);
      expect(result.powerWatts, 300);
    });

    test('decodes running speed and cadence', () {
      final result = HealthBleDecoder.decode(
        '2a53',
        Uint8List.fromList([
          0x02,
          0x00, 0x03, // 3 m/s
          160,
          0x39, 0x30, 0x00, 0x00, // 1234.5 m
        ]),
      );

      expect(result.speedKmh, closeTo(10.8, 0.01));
      expect(result.cadenceRpm, 160);
      expect(result.distanceMeters, 1234.5);
    });

    test('decodes cycling power and continuous pulse oximetry', () {
      final power = HealthBleDecoder.decode(
        '2a63',
        Uint8List.fromList([0, 0, 250, 0]),
      );
      final oxygen = HealthBleDecoder.decode(
        '2a5f',
        Uint8List.fromList([0, 97, 0, 65, 0]),
      );

      expect(power.powerWatts, 250);
      expect(oxygen.spo2Percent, 97);
      expect(oxygen.heartRate, 65);
    });

    test('rejects truncated packets without throwing', () {
      final result = HealthBleDecoder.decode(
        '2ad2',
        Uint8List.fromList([0x54]),
      );

      expect(result.hasMeasurements, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('blocks writes to CGM and insulin delivery systems', () {
      const device = DeviceConnection(
        id: 'medical-device',
        title: 'CGM Sensor',
        type: 'глюкометр / CGM',
        enabled: true,
        lastSync: '',
        permissions: 'только чтение',
        features: ['непрерывная глюкоза'],
      );
      const cgmCommand = BleWriteCommand(
        id: 'cgm-command',
        title: 'Запись CGM',
        serviceUuid: '0000181F-0000-1000-8000-00805F9B34FB',
        characteristicUuid: '2aa7',
        payloadHex: '01',
      );
      const insulinCommand = BleWriteCommand(
        id: 'insulin-command',
        title: 'Команда помпы',
        serviceUuid: '183a',
        characteristicUuid: '2d1a',
        payloadHex: '01',
      );

      expect(
        HealthBleService.isProtectedMedicalWrite(device, cgmCommand),
        isTrue,
      );
      expect(
        HealthBleService.isProtectedMedicalWrite(device, insulinCommand),
        isTrue,
      );
    });
  });
}
