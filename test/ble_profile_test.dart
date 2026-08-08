import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/model.dart';

void main() {
  test(
    'persists user BLE mappings and write commands with device connection',
    () {
      final state = HealthAppState.seed().copyWith(
        devices: const [
          DeviceConnection(
            id: 'device-1',
            title: 'Custom band',
            type: 'Bluetooth LE',
            enabled: true,
            lastSync: '',
            permissions: 'пользовательские BLE-сервисы',
            deviceId: 'ble-1',
            services: ['fff0'],
            features: ['Шаги'],
            bleMappings: [
              BleCharacteristicMapping(
                id: 'mapping-1',
                title: 'Шаги браслета',
                serviceUuid: 'fff0',
                characteristicUuid: 'fff1',
                metric: 'steps',
                parser: 'uint32le',
                unit: 'шагов',
                scale: 1,
              ),
            ],
            bleCommands: [
              BleWriteCommand(
                id: 'command-1',
                title: 'Запуск измерения',
                serviceUuid: 'fff0',
                characteristicUuid: 'fff2',
                payloadHex: '01 00 FF',
                withoutResponse: true,
                runBeforeSync: true,
                delayMs: 500,
              ),
            ],
          ),
        ],
      );

      final restored = HealthAppState.fromJson(state.toJson());
      final mapping = restored.devices.single.bleMappings.single;
      final command = restored.devices.single.bleCommands.single;

      expect(mapping.title, 'Шаги браслета');
      expect(mapping.metric, 'steps');
      expect(mapping.parser, 'uint32le');
      expect(mapping.serviceUuid, 'fff0');
      expect(mapping.characteristicUuid, 'fff1');
      expect(command.title, 'Запуск измерения');
      expect(command.payloadHex, '01 00 FF');
      expect(command.withoutResponse, isTrue);
      expect(command.runBeforeSync, isTrue);
      expect(command.delayMs, 500);
    },
  );
}
