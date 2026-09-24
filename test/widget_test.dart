import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:my_health/src/app.dart';
import 'package:my_health/src/model.dart';
import 'package:my_health/src/repository.dart';
import 'package:my_health/src/screens.dart' hide Text;
import 'package:my_health/src/widgets.dart';

void main() {
  testWidgets('shows first-run setup when onboarding is not complete', (
    tester,
  ) async {
    final state = HealthAppState.seed();

    await tester.pumpWidget(
      MyHealthApp(
        repository: InMemoryHealthRepository(state),
        initialState: state,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Первичная настройка'), findsOneWidget);
    expect(find.textContaining('Выбор языка'), findsOneWidget);
  });

  testWidgets('shows the Today dashboard for a configured user', (
    tester,
  ) async {
    final state = HealthAppState.seed().copyWith(onboardingComplete: true);

    await tester.pumpWidget(
      MyHealthApp(
        repository: InMemoryHealthRepository(state),
        initialState: state,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Готовность'), findsOneWidget);
    expect(find.text('Базовый расход'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('справочная информация'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('справочная информация'), findsOneWidget);
  });

  testWidgets('Today keeps five compact gauges on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = HealthAppState.seed().copyWith(onboardingComplete: true);

    await tester.pumpWidget(
      MyHealthApp(
        repository: InMemoryHealthRepository(state),
        initialState: state,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CompactGauge), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('medicine names remain horizontal on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var state = HealthAppState.seed().copyWith(
      onboardingComplete: true,
      medications: const [
        Medication(
          id: 'medicine-layout',
          name: 'Метформин пролонгированного действия',
          dose: '500 мг',
          schedule: '08:00',
          takenToday: false,
          notes: '',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: MedicinesScreen(
            state: state,
            onChanged: (updated) => state = updated,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.textContaining('Метформин пролонгированного действия');
    expect(title, findsOneWidget);
    expect(tester.getSize(title).width, greaterThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('back restores the previous section before requesting exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = HealthAppState.seed().copyWith(onboardingComplete: true);
    var exitRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: MyHealthShell(
          state: state,
          onChanged: (_) {},
          onExitRequested: () async => exitRequested = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Добавить или спросить'), findsOneWidget);

    await tester.tap(find.text('Здоровье').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('справочная информация'), findsOneWidget);
    expect(find.byTooltip('Добавить или спросить'), findsOneWidget);

    await tester.tap(find.byTooltip('Добавить или спросить'));
    await tester.pumpAndSettle();
    expect(find.text('Добавить информацию или спросить'), findsOneWidget);
    expect(find.byTooltip('Голосовой ввод на русском'), findsOneWidget);
    expect(find.byTooltip('Сфотографировать'), findsOneWidget);
    expect(find.byTooltip('Приложить файл'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Готовность'), findsOneWidget);
    expect(exitRequested, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exitRequested, isTrue);
  });

  testWidgets('root back asks before exiting the application', (tester) async {
    final state = HealthAppState.seed().copyWith(onboardingComplete: true);
    await tester.pumpWidget(
      MyHealthApp(
        repository: InMemoryHealthRepository(state),
        initialState: state,
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsOneWidget);
    expect(find.textContaining('Обычное сворачивание'), findsOneWidget);

    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsNothing);
    expect(find.text('Готовность'), findsOneWidget);
  });

  testWidgets('onboarding steps do not overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = HealthAppState.seed();

    await tester.pumpWidget(
      MyHealthApp(
        repository: InMemoryHealthRepository(state),
        initialState: state,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var step = 0; step < 14; step++) {
      await _tapOnboardingNext(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    expect(find.textContaining('Мотивация'), findsOneWidget);
  });

  testWidgets('quick add meal does not invent calories or macros', (
    tester,
  ) async {
    var state = HealthAppState.seed().copyWith(onboardingComplete: true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showQuickAddDialog(
                context,
                state,
                (updated) => state = updated,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(7), 'Творог');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(state.meals, hasLength(1));
    expect(state.meals.single.title, 'Творог');
    expect(state.meals.single.kind, 'перекус');
    expect(state.meals.single.calories, 0);
    expect(state.meals.single.protein, 0);
    expect(state.meals.single.carbs, 0);
    expect(state.meals.single.fat, 0);
    expect(state.today.calories, 0);
  });

  testWidgets(
    'nutrition add meal starts without estimated calories or macros',
    (tester) async {
      var state = HealthAppState.seed().copyWith(onboardingComplete: true);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: NutritionScreen(
              state: state,
              onChanged: (updated) => state = updated,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Еда'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Омлет');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(state.meals, hasLength(1));
      expect(state.meals.single.title, 'Омлет');
      expect(state.meals.single.kind, 'обед');
      expect(state.meals.single.calories, 0);
      expect(state.meals.single.protein, 0);
      expect(state.meals.single.carbs, 0);
      expect(state.meals.single.fat, 0);
      expect(state.today.calories, 0);
    },
  );

  testWidgets('manual workout add starts without estimated plan data', (
    tester,
  ) async {
    var state = HealthAppState.seed().copyWith(onboardingComplete: true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: WorkoutsScreen(
            state: state,
            onChanged: (updated) => state = updated,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Тренировка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Растяжка');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(state.workouts, hasLength(1));
    expect(state.workouts.single.title, 'Растяжка');
    expect(state.workouts.single.minutes, 0);
    expect(state.workouts.single.exerciseIds, isEmpty);
    expect(state.today.workoutMinutes, 0);
  });

  testWidgets('lab OCR confirmation keeps missing values empty', (
    tester,
  ) async {
    var state = HealthAppState.seed().copyWith(
      onboardingComplete: true,
      confirmationQueue: const [
        RecognitionCandidate(
          id: 'lab-ocr-empty',
          source: 'OCR анализа',
          title: 'Файл анализа без чисел',
          confidence: 0.12,
          requiresMedicalReview: true,
          kind: 'file',
          createdAt: '2026-06-15',
          metadata: {'rawText': 'анализ крови'},
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: LabsScreen(
            state: state,
            onChanged: (updated) => state = updated,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Подтвердить'));
    await tester.pumpAndSettle();

    expect(state.confirmationQueue, isEmpty);
    expect(state.labResults, hasLength(1));
    expect(state.labResults.single.marker, 'Файл анализа без чисел');
    expect(state.labResults.single.value, isEmpty);
    expect(state.labResults.single.unit, isEmpty);
    expect(state.labResults.single.reference, isEmpty);
    expect(state.labResults.single.notes, contains('Не извлечено'));
    expect(state.labResults.single.notes, isNot(contains('подтверждено')));
    expect(state.labResults.single.notes, isNot(contains('см. оригинал')));
  });

  testWidgets('food OCR confirmation does not invent calories or macros', (
    tester,
  ) async {
    var state = HealthAppState.seed().copyWith(
      onboardingComplete: true,
      confirmationQueue: const [
        RecognitionCandidate(
          id: 'food-ocr-empty',
          source: 'фото еды',
          title: 'Фото тарелки',
          confidence: 0.18,
          requiresMedicalReview: false,
          kind: 'image',
          createdAt: '2026-06-15',
          metadata: {'rawText': 'photo.jpg'},
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: FoodPhotoScreen(
            state: state,
            onChanged: (updated) => state = updated,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Подтвердить'));
    await tester.pumpAndSettle();

    expect(state.confirmationQueue, isEmpty);
    expect(state.meals, hasLength(1));
    expect(state.meals.single.calories, 0);
    expect(state.meals.single.protein, 0);
    expect(state.meals.single.carbs, 0);
    expect(state.meals.single.fat, 0);
    expect(state.metricsFor('2026-06-15').calories, 0);
  });
}

Future<void> _tapOnboardingNext(WidgetTester tester) async {
  final listView = find.byType(ListView).first;
  for (var attempt = 0; attempt < 8; attempt++) {
    final buttons = find.byType(FilledButton);
    if (buttons.evaluate().isNotEmpty) {
      final nextButton = buttons.last;
      await tester.ensureVisible(nextButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(nextButton);
      return;
    }
    await tester.drag(listView, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
  fail('Onboarding next button was not reachable on a narrow screen.');
}
