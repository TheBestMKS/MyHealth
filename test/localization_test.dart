import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/generated_ui_translations.dart';
import 'package:my_health/src/localization.dart';
import 'package:my_health/src/widgets.dart';

void main() {
  final cyrillic = RegExp(r'[\u0400-\u04ff]');

  test('all configured non-Russian locales have a complete generated map', () {
    final locales = supportedLanguages
        .map((language) => language.code)
        .where((code) => code != 'ru');
    for (final locale in locales) {
      final translations = generatedUiTranslations[locale];
      expect(translations, isNotNull, reason: 'missing locale $locale');
      expect(
        translations!.length,
        greaterThanOrEqualTo(1500),
        reason: 'incomplete locale $locale',
      );
      expect(
        translations.values.where((value) => value.trim().isEmpty),
        isEmpty,
        reason: 'blank translations in $locale',
      );
    }
  });

  test('semantic and interpolated English text does not leak Russian UI', () {
    expect(AppText.get('en', 'settings'), 'Settings');
    expect(AppText.get('be', 'settings'), isNot('Настройки'));
    expect(AppText.get('kk', 'settings'), isNot('Настройки'));
    expect(
      cyrillic.hasMatch(
        AppText.phraseFor('en', 'Запланировано уведомлений: 12'),
      ),
      isFalse,
    );
  });

  test('new assistant, climate and document-vault phrases are translated', () {
    const critical = [
      'Факты из приложения:',
      'Климатический профиль',
      'Напечатать отчёт для врача',
      'Не удалось защитить исходный анализ:',
      'Версия: 1.8.2+11',
      'Диагностика',
      'Журнал ошибок',
      'Копировать журнал',
      'Очистить журнал ошибок?',
    ];
    for (final language in supportedLanguages.where(
      (item) => item.code != 'ru',
    )) {
      final translations = generatedUiTranslations[language.code]!;
      for (final phrase in critical) {
        expect(
          translations[phrase],
          isNotNull,
          reason: 'missing $phrase in ${language.code}',
        );
        final isSharedKazakhTerm =
            language.code == 'kk' && phrase == 'Диагностика';
        if (!isSharedKazakhTerm) {
          expect(
            translations[phrase],
            isNot(phrase),
            reason: 'untranslated $phrase in ${language.code}',
          );
        }
      }
    }
    expect(
      generatedUiTranslations['en']!['Факты из приложения:'],
      'Facts from the app:',
    );
    expect(generatedUiTranslations['en']!['Журнал ошибок'], 'Error log');
  });

  testWidgets('shared controls localize text, decorations and tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              const LocalizedText('Медицинский сейф заблокирован'),
              const LocalizedTextField(
                decoration: InputDecoration(
                  labelText: 'Имя',
                  hintText: 'Например: силовая дома',
                  helperText: 'Выберите страну проживания',
                ),
              ),
              LocalizedIconButton(
                tooltip: 'Выбрать дату',
                onPressed: () {},
                icon: const Icon(Icons.calendar_today_outlined),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(cyrillic.hasMatch(textField.decoration?.labelText ?? ''), isFalse);
    expect(cyrillic.hasMatch(textField.decoration?.hintText ?? ''), isFalse);
    expect(cyrillic.hasMatch(textField.decoration?.helperText ?? ''), isFalse);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(cyrillic.hasMatch(tooltip.message ?? ''), isFalse);
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .where((value) => value.isNotEmpty);
    expect(visibleText.where(cyrillic.hasMatch), isEmpty);
  });
}
