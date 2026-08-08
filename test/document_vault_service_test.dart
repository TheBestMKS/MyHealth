import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/document_vault_service.dart';

void main() {
  test(
    'encrypts an attachment and materializes an exact temporary copy',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'my-health-vault-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}${Platform.pathSeparator}анализ.txt');
      final bytes = utf8.encode('Гемоглобин: 145 г/л');
      await source.writeAsBytes(bytes);
      final service = DocumentVaultService(
        rootDirectory: root,
        cacheDirectory: root,
        testKey: SecretKey(List<int>.generate(32, (index) => index)),
      );

      final stored = await service.importFile(source.path, 'document-1');

      expect(service.isVaultPath(stored), isTrue);
      expect(await source.exists(), isTrue);
      expect(await File(stored).readAsString(), isNot(contains('Гемоглобин')));

      final materialized = await service.materialize(stored);
      expect(await materialized.readAsBytes(), bytes);
      expect(materialized.path, contains('анализ.txt'));

      await service.deleteStoredFile(stored);
      expect(await File(stored).exists(), isFalse);
    },
  );
}
