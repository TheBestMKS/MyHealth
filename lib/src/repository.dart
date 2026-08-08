import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import 'localization.dart';
import 'model.dart';
import 'document_vault_service.dart';

abstract class HealthRepository {
  Future<HealthAppState> load();

  Future<void> save(HealthAppState state);
}

class InMemoryHealthRepository implements HealthRepository {
  InMemoryHealthRepository([HealthAppState? initial])
    : _state = initial ?? HealthAppState.seed();

  HealthAppState _state;

  @override
  Future<HealthAppState> load() async => _state;

  @override
  Future<void> save(HealthAppState state) async {
    _state = state;
  }
}

class FileHealthRepository implements HealthRepository {
  FileHealthRepository({AesGcm? cipher})
    : _cipher = cipher ?? AesGcm.with256bits();

  static const _vaultFileName = 'my_health_vault.json';
  static const _vaultVersion = 1;
  static const _vaultKeyName = 'my_health_vault_key_v2';
  static const _secureStorage = FlutterSecureStorage();
  static final SecretKey _legacySecretKey = SecretKey(
    List<int>.generate(
      32,
      (index) => 'my-health-local-vault-2026'.codeUnitAt(index % 26),
    ),
  );

  final AesGcm _cipher;

  @override
  Future<HealthAppState> load() async {
    final file = await _file();
    if (!await file.exists()) {
      return HealthAppState.seed();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic> && decoded['encrypted'] == true) {
        final box = SecretBox(
          base64Decode(decoded['cipherText'] as String),
          nonce: base64Decode(decoded['nonce'] as String),
          mac: Mac(base64Decode(decoded['mac'] as String)),
        );
        final key = await _loadSecretKey();
        try {
          final bytes = await _cipher.decrypt(box, secretKey: key);
          return HealthAppState.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          );
        } catch (_) {
          final bytes = await _cipher.decrypt(box, secretKey: _legacySecretKey);
          final migrated = HealthAppState.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
          );
          await save(migrated);
          return migrated;
        }
      }
      if (decoded is Map<String, dynamic>) {
        return HealthAppState.fromJson(decoded);
      }
    } catch (_) {
      final backup = File(
        '${file.path}.broken-${DateTime.now().millisecondsSinceEpoch}',
      );
      await file.rename(backup.path);
    }
    return HealthAppState.seed();
  }

  @override
  Future<void> save(HealthAppState state) async {
    final file = await _file();
    await file.parent.create(recursive: true);

    final source = utf8.encode(jsonEncode(state.toJson()));
    if (state.settings.encryptedVault) {
      final nonce = _cipher.newNonce();
      final encrypted = await _cipher.encrypt(
        source,
        secretKey: await _loadSecretKey(),
        nonce: nonce,
      );
      final payload = {
        'schema': _vaultVersion,
        'encrypted': true,
        'nonce': base64Encode(encrypted.nonce),
        'cipherText': base64Encode(encrypted.cipherText),
        'mac': base64Encode(encrypted.mac.bytes),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
      return;
    }

    await file.writeAsString(jsonEncode(state.toJson()), flush: true);
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_vaultFileName');
  }

  Future<SecretKey> _loadSecretKey() async {
    try {
      final saved = await _secureStorage.read(key: _vaultKeyName);
      if (saved != null && saved.isNotEmpty) {
        return SecretKey(base64Decode(saved));
      }
      final random = Random.secure();
      final generated = List<int>.generate(32, (_) => random.nextInt(256));
      await _secureStorage.write(
        key: _vaultKeyName,
        value: base64Encode(generated),
      );
      return SecretKey(generated);
    } catch (_) {
      final vault = await _file();
      final keyFile = File('${vault.path}.key');
      if (await keyFile.exists()) {
        return SecretKey(base64Decode(await keyFile.readAsString()));
      }
      final random = Random.secure();
      final generated = List<int>.generate(32, (_) => random.nextInt(256));
      await keyFile.writeAsString(base64Encode(generated), flush: true);
      return SecretKey(generated);
    }
  }
}

class ReportService {
  Future<File> exportDoctorPdf(HealthAppState state) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}my_health_report_${todayKey()}.pdf',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await buildDoctorPdf(state), flush: true);
    return file;
  }

  Future<Uint8List> buildDoctorPdf(HealthAppState state) async {
    final fontData = await rootBundle.load('assets/fonts/roboto-regular.ttf');
    final font = pw.Font.ttf(fontData);
    final doc = pw.Document();
    final textStyle = pw.TextStyle(font: font, fontSize: 10);
    final titleStyle = pw.TextStyle(font: font, fontSize: 20);
    final headerStyle = pw.TextStyle(font: font, fontSize: 13);
    String t(String source) => AppText.phraseFor(state.localeCode, source);

    pw.Widget line(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text('${t(label)}: $value', style: textStyle),
    );

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(t('Моё здоровье: отчёт для врача'), style: titleStyle),
          pw.SizedBox(height: 8),
          pw.Text(
            AppText.get(state.localeCode, 'medicalDisclaimer'),
            style: textStyle,
          ),
          pw.SizedBox(height: 18),
          pw.Text(t('Профиль'), style: headerStyle),
          line('Имя', state.profile.name),
          line('Возраст', '${state.profile.age}'),
          line(
            'Рост',
            '${state.profile.heightCm.toStringAsFixed(0)} ${t('см')}',
          ),
          line('Вес', '${state.today.weightKg.toStringAsFixed(1)} ${t('кг')}'),
          line(
            'Город и климат',
            '${state.profile.city}, ${state.profile.climate}',
          ),
          pw.SizedBox(height: 12),
          pw.Text(t('Сегодня'), style: headerStyle),
          line('Готовность', '${state.readinessScore}/100'),
          line('Энергия', '${state.energyScore}/100'),
          line('Сон', '${state.today.sleepHours.toStringAsFixed(1)} ${t('ч')}'),
          line('Шаги', '${state.today.steps}'),
          line(
            'Вода',
            '${state.today.waterLiters.toStringAsFixed(1)} ${t('л')}',
          ),
          line('Калории', '${state.today.calories}'),
          line('Тренировка', '${state.today.workoutMinutes} ${t('мин')}'),
          pw.SizedBox(height: 12),
          pw.Text(t('Медицинская карта'), style: headerStyle),
          line('Хронические состояния', state.chronicConditions.join(', ')),
          line('Аллергии', state.allergies.join(', ')),
          line('Противопоказания', state.contraindications.join(', ')),
          pw.SizedBox(height: 12),
          pw.Text(t('Лекарства'), style: headerStyle),
          ...state.medications.map(
            (item) => line(item.name, '${item.dose}; ${item.schedule}'),
          ),
          ...state.medicationIntakes.map(
            (item) => line(
              '${t('Приём')} ${item.date} ${item.time}',
              '${item.medicationName}; ${item.dose}; ${item.status}; ${item.notes}',
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(t('Анализы'), style: headerStyle),
          ...state.labResults.map(
            (item) => line(
              item.marker,
              '${item.value} ${item.unit}; ${t('референс')} ${item.reference}; ${item.date}',
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(t('ИИ-заметки и подтверждения'), style: headerStyle),
          ...state.insights.map((item) => line('Рекомендация', item)),
          ...state.confirmationQueue.map(
            (item) => line(
              item.source,
              '${item.title}; ${t('уверенность')} ${(item.confidence * 100).round()}%',
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }
}

class BackupService {
  Future<File> exportJson(HealthAppState state) async {
    final directory = await _backupDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}my_health_backup_${todayKey()}.json',
    );
    final backup = state.toJson();
    final attachments = <String, dynamic>{};
    for (final document in state.documents) {
      if (document.filePath.isEmpty) continue;
      try {
        final file = await DocumentVaultService.instance.materialize(
          document.filePath,
        );
        if (!await file.exists()) continue;
        attachments[document.id] = {
          'name': document.fileName.isEmpty
              ? file.path.split(RegExp(r'[\\/]')).last
              : document.fileName,
          'data': base64Encode(await file.readAsBytes()),
        };
      } catch (_) {
        // The rest of the backup remains usable if one external file vanished.
      }
    }
    backup['backupFormat'] = 2;
    backup['documentAttachments'] = attachments;
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(backup),
      encoding: utf8,
      flush: true,
    );
    return file;
  }

  Future<List<File>> exportCsvTables(HealthAppState state) async {
    final directory = await _backupDirectory();
    final converter = const ListToCsvConverter(fieldDelimiter: ';');
    Future<File> write(String name, List<List<Object?>> rows) async {
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      final body = converter.convert(rows);
      await file.writeAsBytes([
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(body),
      ], flush: true);
      return file;
    }

    return [
      await write('nutrition_${todayKey()}.csv', [
        const [
          'date',
          'time',
          'title',
          'kind',
          'portion_g',
          'calories',
          'protein_g',
          'fat_g',
          'carbs_g',
          'sugar_g',
          'fiber_g',
          'salt_g',
          'notes',
        ],
        for (final item in state.meals)
          [
            item.date,
            item.time,
            item.title,
            item.kind,
            item.portionGrams,
            item.calories,
            item.protein,
            item.fat,
            item.carbs,
            item.sugar,
            item.fiber,
            item.salt,
            item.notes,
          ],
      ]),
      await write('workouts_${todayKey()}.csv', [
        const [
          'date',
          'title',
          'focus',
          'status',
          'minutes',
          'distance_m',
          'calories_burned',
          'effort',
          'feedback',
          'notes',
        ],
        for (final item in state.workouts)
          [
            item.scheduledDate,
            item.title,
            item.focus,
            item.status,
            item.minutes,
            item.distanceMeters,
            item.caloriesBurned,
            item.perceivedEffort,
            item.feedback,
            item.notes,
          ],
      ]),
      await write('labs_${todayKey()}.csv', [
        const [
          'date',
          'marker',
          'value',
          'unit',
          'reference',
          'status',
          'notes',
        ],
        for (final item in state.labResults)
          [
            item.date,
            item.marker,
            item.value,
            item.unit,
            item.reference,
            item.referenceStatus,
            item.notes,
          ],
      ]),
    ];
  }

  Future<HealthAppState?> importJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    final selected = result?.files.single;
    if (selected == null) return null;
    final content = selected.path == null
        ? utf8.decode(selected.bytes ?? const [])
        : await File(selected.path!).readAsString(encoding: utf8);
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException(
        'Файл не содержит резервную копию приложения.',
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    if (!map.containsKey('profile') || !map.containsKey('settings')) {
      throw const FormatException('Структура резервной копии не распознана.');
    }
    var state = HealthAppState.fromJson(map);
    final rawAttachments = map['documentAttachments'];
    if (rawAttachments is Map) {
      final restoredDocuments = <HealthDocument>[];
      for (final document in state.documents) {
        final raw = rawAttachments[document.id];
        if (raw is! Map) {
          restoredDocuments.add(document);
          continue;
        }
        try {
          final attachment = Map<String, dynamic>.from(raw);
          final name = attachment['name'] as String? ?? 'document.bin';
          final data = attachment['data'] as String? ?? '';
          final path = await DocumentVaultService.instance.importBytes(
            base64Decode(data),
            fileName: name,
            documentId: document.id,
          );
          restoredDocuments.add(
            document.copyWith(filePath: path, fileName: name),
          );
        } catch (_) {
          restoredDocuments.add(document);
        }
      }
      state = state.copyWith(documents: restoredDocuments);
    }
    return state;
  }

  Future<Directory> _backupDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}MyHealth${Platform.pathSeparator}Backups',
    );
    await directory.create(recursive: true);
    return directory;
  }
}
