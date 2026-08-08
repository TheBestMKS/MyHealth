import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'date_input.dart';
import 'localization.dart';
import 'location_catalog.dart';
import 'model.dart';
import 'navigation.dart';
import 'notification_service.dart';
import 'repository.dart';
import 'screens.dart' hide Text;
import 'vault_unlock_screen.dart';
import 'widgets.dart';
import 'world_city_database.dart';

class MyHealthApp extends StatefulWidget {
  const MyHealthApp({super.key, required this.repository, this.initialState});

  final HealthRepository repository;
  final HealthAppState? initialState;

  @override
  State<MyHealthApp> createState() => _MyHealthAppState();
}

class _MyHealthAppState extends State<MyHealthApp> with WidgetsBindingObserver {
  HealthAppState? _state;
  Object? _loadError;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _state?.settings.pinEnabled == true &&
        _unlocked) {
      setState(() => _unlocked = false);
    }
  }

  Future<void> _load() async {
    try {
      final loaded = widget.initialState ?? await widget.repository.load();
      if (!mounted) {
        return;
      }
      final normalized =
          loaded.settings.pinEnabled && loaded.settings.pinHash.isEmpty
          ? loaded.copyWith(
              settings: loaded.settings.copyWith(pinEnabled: false),
            )
          : loaded;
      setState(() {
        _state = normalized;
        _unlocked = !normalized.settings.pinEnabled;
      });
      unawaited(HealthNotificationService.instance.sync(normalized));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _state = HealthAppState.seed();
      });
    }
  }

  void _update(HealthAppState state) {
    setState(() => _state = state);
    unawaited(widget.repository.save(state));
    unawaited(HealthNotificationService.instance.sync(state));
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final localeCode = state?.localeCode ?? 'ru';
    return MaterialApp(
      title: AppText.get(localeCode, 'appName'),
      debugShowCheckedModeBanner: false,
      locale: Locale(localeCode),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(
        Brightness.light,
        state?.settings.highContrast ?? false,
        state?.settings.uiScale ?? 1,
      ),
      darkTheme: _theme(
        Brightness.dark,
        state?.settings.highContrast ?? false,
        state?.settings.uiScale ?? 1,
      ),
      themeMode: _themeMode(state?.settings.themeMode ?? 'system'),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final uiScale = state?.settings.uiScale ?? 1.0;
        final textScale =
            uiScale * (state?.settings.largeText == true ? 1.14 : 1.0);
        return IconTheme(
          data: IconThemeData(size: 24 * uiScale),
          child: MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: state == null
          ? LoadingScreen(localeCode: localeCode)
          : state.onboardingComplete
          ? state.settings.pinEnabled && !_unlocked
                ? VaultUnlockScreen(
                    state: state,
                    onUnlocked: () => setState(() => _unlocked = true),
                  )
                : MyHealthShell(
                    state: state,
                    onChanged: _update,
                    loadError: _loadError,
                  )
          : OnboardingFlow(
              state: state,
              onComplete: (updated) =>
                  _update(updated.copyWith(onboardingComplete: true)),
            ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, required this.localeCode});

  final String localeCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              LocalizedText(
                AppText.get(localeCode, 'loading'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyHealthShell extends StatefulWidget {
  const MyHealthShell({
    super.key,
    required this.state,
    required this.onChanged,
    this.loadError,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;
  final Object? loadError;

  @override
  State<MyHealthShell> createState() => _MyHealthShellState();
}

class _MyHealthShellState extends State<MyHealthShell> {
  AppSection _selected = AppSection.today;
  final _reportService = ReportService();

  @override
  void initState() {
    super.initState();
    HealthNotificationService.instance.activePayload.addListener(
      _handleNotificationPayload,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationPayload();
    });
  }

  @override
  void dispose() {
    HealthNotificationService.instance.activePayload.removeListener(
      _handleNotificationPayload,
    );
    super.dispose();
  }

  void _handleNotificationPayload() {
    if (!mounted) return;
    final notifier = HealthNotificationService.instance.activePayload;
    final payload = notifier.value;
    if (payload == null || payload.isEmpty) return;
    notifier.value = null;
    if (payload.startsWith('alarm:')) {
      final rawAlarm = payload.substring('alarm:'.length);
      final occurrence = RegExp(
        r'^(.*):(\d{4}-\d{2}-\d{2})$',
      ).firstMatch(rawAlarm);
      final id = occurrence?.group(1) ?? rawAlarm;
      final dateKey = occurrence?.group(2);
      final alarm = widget.state.alarmGroups
          .where((item) => item.id == id)
          .firstOrNull;
      if (alarm != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showAlarmChallenge(context, alarm, dateKey: dateKey);
          }
        });
      }
      return;
    }
    setState(() {
      _selected = payload.startsWith('medicine:')
          ? AppSection.medicines
          : AppSection.today;
    });
  }

  void _select(AppSection section) {
    setState(() => _selected = section);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final locale = state.localeCode;
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 900;
    final body = buildSectionScreen(
      _selected,
      state,
      widget.onChanged,
      _select,
    );

    return Scaffold(
      appBar: AppBar(
        title: LocalizedText(sectionInfo(_selected).label(locale)),
        actions: [
          LocalizedIconButton(
            tooltip: AppText.get(locale, 'search'),
            onPressed: () => showGlobalSearch(context, state, _select),
            icon: const Icon(Icons.search),
          ),
          LocalizedIconButton(
            tooltip: AppText.get(locale, 'quickAdd'),
            onPressed: () =>
                showQuickAddDialog(context, state, widget.onChanged),
            icon: const Icon(Icons.add_circle_outline),
          ),
          LocalizedIconButton(
            tooltip: AppText.get(locale, 'exportPdf'),
            onPressed: () => _exportPdf(context),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          LocalizedIconButton(
            tooltip: AppText.get(locale, 'theme'),
            onPressed: () {
              final next = state.settings.themeMode == 'dark'
                  ? 'light'
                  : 'dark';
              widget.onChanged(
                state.copyWith(
                  settings: state.settings.copyWith(themeMode: next),
                ),
              );
            },
            icon: Icon(
              state.settings.themeMode == 'dark'
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Row(
        children: [
          if (useRail)
            _DesktopNavigation(
              state: state,
              selected: _selected,
              onSelect: _select,
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: body),
                if (widget.loadError != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LocalizedText(
                          'Vault был восстановлен из безопасного начального состояния.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : _MobileNavigation(
              state: state,
              selected: _selected,
              onSelect: _select,
              onMore: () => _showMoreSheet(context),
            ),
      floatingActionButton: useRail
          ? null
          : FloatingActionButton(
              tooltip: AppText.get(locale, 'quickAdd'),
              onPressed: () =>
                  showQuickAddDialog(context, state, widget.onChanged),
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _reportService.exportDoctorPdf(widget.state);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: LocalizedText('PDF-отчёт создан: ${file.path}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: LocalizedText('Не удалось создать PDF: $error')),
      );
    }
  }

  void _showMoreSheet(BuildContext context) {
    final state = widget.state;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final hidden = allSections.where(
          (item) =>
              item.section != AppSection.home &&
              item.section != AppSection.health &&
              !mobileSections.contains(item.section),
        );
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in hidden)
                ListTile(
                  leading: Icon(item.icon),
                  title: LocalizedText(item.label(state.localeCode)),
                  selected: _selected == item.section,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _select(item.section);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final HealthAppState state;
  final AppSection selected;
  final SectionSelected onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 284,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: LocalizedText(
                AppText.get(state.localeCode, 'appName'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LocalizedText(
                state.settings.offlineOnly
                    ? 'Офлайн · локальный сейф'
                    : 'Синхронизация разрешена',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  for (final item in allSections)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child:
                          NavigationDrawerDestination(
                            icon: Icon(item.icon),
                            label: LocalizedText(item.label(state.localeCode)),
                            selectedIcon: Icon(item.icon),
                          ).asListTile(
                            context,
                            selected: selected == item.section,
                            onTap: () => onSelect(item.section),
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onMore,
  });

  final HealthAppState state;
  final AppSection selected;
  final SectionSelected onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = mobileSections.contains(selected)
        ? mobileSections.indexOf(selected)
        : mobileSections.length;
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == mobileSections.length) {
          onMore();
          return;
        }
        onSelect(mobileSections[index]);
      },
      destinations: [
        for (final section in mobileSections)
          NavigationDestination(
            icon: Icon(sectionInfo(section).icon),
            label: sectionInfo(section).label(state.localeCode),
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz),
          label: AppText.get(state.localeCode, 'more'),
        ),
      ],
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.state,
    required this.onComplete,
  });

  final HealthAppState state;
  final HealthStateChanged onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late HealthAppState _draft;
  int _step = 0;

  late final TextEditingController _name;
  late final TextEditingController _birthDate;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _goal;
  late final TextEditingController _worldCityQuery;
  final Set<String> _trainingGoals = {};
  String _selectedCountry = '';
  String _selectedCity = '';
  List<WorldCityEntry> _worldCityResults = const [];
  String _worldCityStatus = '';
  int _worldCitySearchSerial = 0;

  static const _steps = [
    'Выбор языка',
    'Профиль',
    'Цель',
    'Параметры здоровья',
    'Хронические состояния',
    'Аллергии',
    'Противопоказания',
    'Место и климат',
    'Активность',
    'Инвентарь',
    'Питание',
    'Будильники',
    'Устройства',
    'Приватность',
    'Мотивация',
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.state;
    _name = TextEditingController(text: _draft.profile.name);
    _birthDate = TextEditingController(
      text: dateInputText(_draft.profile.birthDate),
    );
    _height = TextEditingController(
      text: _draft.profile.heightCm == 0
          ? ''
          : _draft.profile.heightCm.toStringAsFixed(0),
    );
    _weight = TextEditingController(
      text: _draft.profile.weightKg == 0
          ? ''
          : _draft.profile.weightKg.toStringAsFixed(1),
    );
    _goal = TextEditingController(text: _draft.profile.goal);
    _worldCityQuery = TextEditingController(text: _draft.profile.city);
    _trainingGoals.addAll(_draft.profile.trainingGoals);
    if (_trainingGoals.isEmpty && _draft.profile.goal.isNotEmpty) {
      _trainingGoals.addAll(
        _draft.profile.goal
            .split(RegExp(r'[,;]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
    }
    if (_trainingGoals.length > 1) {
      final first = _trainingGoals.first;
      _trainingGoals
        ..clear()
        ..add(first);
    }
    _selectedCountry = _draft.profile.country;
    _selectedCity = _draft.profile.city;
  }

  @override
  void dispose() {
    _name.dispose();
    _birthDate.dispose();
    _height.dispose();
    _weight.dispose();
    _goal.dispose();
    _worldCityQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = _draft.localeCode;
    return Scaffold(
      appBar: AppBar(
        title: LocalizedText(AppText.get(locale, 'onboardingTitle')),
        actions: [
          TextButton(
            onPressed: () => widget.onComplete(_commitControllers(_draft)),
            child: LocalizedText(AppText.get(locale, 'skipOptional')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              LocalizedText(
                AppText.get(locale, 'onboardingSubtitle'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_step + 1) / _steps.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 16),
              LocalizedText(
                '${_step + 1}/${_steps.length} · ${_steps[_step]}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _stepContent(context),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_step > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _step--),
                      icon: const Icon(Icons.arrow_back),
                      label: LocalizedText(AppText.get(locale, 'back')),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      final committed = _commitControllers(_draft);
                      if (_step == _steps.length - 1) {
                        widget.onComplete(committed);
                        return;
                      }
                      setState(() {
                        _draft = committed;
                        _step++;
                      });
                    },
                    icon: Icon(
                      _step == _steps.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                    ),
                    label: LocalizedText(
                      _step == _steps.length - 1
                          ? AppText.get(locale, 'finish')
                          : AppText.get(locale, 'next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context) {
    return switch (_step) {
      0 => _languageStep(),
      1 => _profileStep(),
      2 => _goalStep(),
      3 => _healthParametersStep(),
      4 => _chipStep(
        title: 'Хронические состояния',
        group: 'conditions',
        values: _draft.chronicConditions,
        suggestions: const [
          'астма',
          'гипертония под контролем',
          'мигрень',
          'сахарный диабет',
          'заболевание щитовидной железы',
          'нет хронических состояний',
        ],
        onAdd: (value) => _draft = _draft.copyWith(
          chronicConditions: [..._draft.chronicConditions, value],
        ),
        onRemove: (value) => _draft = _draft.copyWith(
          chronicConditions: _draft.chronicConditions
              .where((item) => item != value)
              .toList(),
        ),
      ),
      5 => _chipStep(
        title: 'Аллергии',
        group: 'allergies',
        values: _draft.allergies,
        suggestions: const [
          'пыльца',
          'лактоза',
          'орехи',
          'пенициллин',
          'пыль',
          'шерсть животных',
          'нет аллергий',
        ],
        onAdd: (value) =>
            _draft = _draft.copyWith(allergies: [..._draft.allergies, value]),
        onRemove: (value) => _draft = _draft.copyWith(
          allergies: _draft.allergies.where((item) => item != value).toList(),
        ),
      ),
      6 => _chipStep(
        title: 'Противопоказания',
        group: 'contraindications',
        values: _draft.contraindications,
        suggestions: const [
          'без прыжков',
          'без тяжёлой осевой нагрузки',
          'не тренироваться при температуре',
          'ограничить бег',
          'избегать задержки дыхания',
          'нет противопоказаний',
        ],
        onAdd: (value) => _draft = _draft.copyWith(
          contraindications: [..._draft.contraindications, value],
        ),
        onRemove: (value) => _draft = _draft.copyWith(
          contraindications: _draft.contraindications
              .where((item) => item != value)
              .toList(),
        ),
      ),
      7 => _climateStep(),
      8 => _activityStep(),
      9 => _chipStep(
        title: 'Инвентарь',
        group: 'inventory',
        values: _draft.inventory,
        suggestions: const [
          'гантели',
          'эспандер',
          'коврик',
          'турник',
          'велотренажёр',
          'резинки',
          'скакалка',
          'штанга',
          'нет инвентаря',
        ],
        onAdd: (value) =>
            _draft = _draft.copyWith(inventory: [..._draft.inventory, value]),
        onRemove: (value) => _draft = _draft.copyWith(
          inventory: _draft.inventory.where((item) => item != value).toList(),
        ),
      ),
      10 => _nutritionPrefsStep(),
      11 => _alarmStep(),
      12 => _devicesStep(),
      13 => _privacyStep(),
      14 => _motivationStep(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _languageStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LocalizedDropdownButtonFormField<String>(
          initialValue: _draft.localeCode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Язык приложения'),
          items: [
            for (final language in supportedLanguages)
              DropdownMenuItem(
                value: language.code,
                child: LocalizedText(
                  '${language.nativeName} · ${language.englishName}',
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _draft = _draft.copyWith(localeCode: value));
            }
          },
        ),
      ),
    );
  }

  Widget _profileStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _onboardingTextField(controller: _name, label: 'Имя'),
            _onboardingTextField(
              controller: _birthDate,
              label: 'Дата рождения',
              hint: 'ДД.ММ.ГГГГ',
              inputFormatters: dateInputFormatters,
              keyboardType: TextInputType.number,
              suffixIcon: LocalizedIconButton(
                tooltip: 'Выбрать дату',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () async {
                  final initial =
                      parseDateKey(_birthDate.text) ??
                      DateTime(DateTime.now().year - 30);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(
                      () => _birthDate.text = dateInputText(todayKey(picked)),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalStep() {
    const goals = [
      'восстановление',
      'снижение веса',
      'набор силы',
      'выносливость',
      'сон и энергия',
      'контроль лекарств',
      'осанка и мобильность',
      'подготовка к бегу',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _onboardingTextField(
              controller: _goal,
              label: 'Своя цель',
              hint: 'Заменяет цель, выбранную ниже',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in goals)
                  FilterChip(
                    label: LocalizedText(value),
                    selected: _trainingGoals.contains(value),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _trainingGoals
                          ..clear()
                          ..add(value);
                        _goal.clear();
                      } else {
                        _trainingGoals.remove(value);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthParametersStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _onboardingTextField(
              controller: _height,
              label: 'Рост, см',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            _onboardingTextField(
              controller: _weight,
              label: 'Вес, кг',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipStep({
    required String title,
    required String group,
    required List<String> values,
    required List<String> suggestions,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
  }) {
    final allSuggestions = [
      ...suggestions,
      ..._draft
          .customLabels(group)
          .where((item) => !suggestions.contains(item)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (values.isEmpty)
                  const LocalizedText(
                    'Ничего не выбрано. Нажмите вариант ниже или добавьте свой.',
                  ),
                for (final item in values)
                  InputChip(
                    label: LocalizedText(item),
                    selected: true,
                    onDeleted: () => setState(() => onRemove(item)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in allSuggestions)
                  ActionChip(
                    label: LocalizedText(item),
                    onPressed: values.contains(item)
                        ? null
                        : () => setState(() {
                            onAdd(item);
                          }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const LocalizedText('Свой вариант'),
                  onPressed: () => _addCustomOption(
                    group: group,
                    title: title,
                    onAdded: (value) {
                      setState(() {
                        _draft = _draft.copyWith(
                          customOptions: [
                            CustomOption(
                              id: newId(),
                              group: group,
                              label: value,
                              metadata: const {},
                            ),
                            ..._draft.customOptions,
                          ],
                        );
                        onAdd(value);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _climateStep() {
    final customCities = _customCities();
    final countryItems = countries(extra: customCities);
    final cityItems = _selectedCountry.isEmpty
        ? const <CityClimate>[]
        : citiesForCountry(_selectedCountry, extra: customCities);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedDropdownButtonFormField<String>(
              initialValue: _selectedCountry.isEmpty ? null : _selectedCountry,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Страна',
                helperText: 'Выберите страну проживания',
              ),
              items: [
                for (final country in countryItems)
                  DropdownMenuItem(
                    value: country,
                    child: LocalizedText(country),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedCountry = value;
                  _selectedCity = '';
                  _draft = _draft.copyWith(
                    profile: _draft.profile.copyWith(country: value, city: ''),
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            LocalizedTextField(
              controller: _worldCityQuery,
              decoration: InputDecoration(
                labelText: 'Поиск города в мировой базе',
                helperText: _worldCityStatus.isEmpty
                    ? 'Введите город прямо здесь: Мурманск, Murmansk, Berlin...'
                    : _worldCityStatus,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: LocalizedIconButton(
                  tooltip: 'Найти город',
                  onPressed: _searchInlineWorldCities,
                  icon: const Icon(Icons.search),
                ),
              ),
              onChanged: (value) {
                if (value.trim().length >= 3) {
                  _searchInlineWorldCities();
                }
              },
              onSubmitted: (_) => _searchInlineWorldCities(),
            ),
            if (_worldCityResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._worldCityResults
                  .take(8)
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_city_outlined),
                      title: LocalizedText(
                        entry.displayName(_draft.localeCode),
                      ),
                      subtitle: LocalizedText(
                        '${entry.displayCountry(_draft.localeCode)} · ${entry.latitude.toStringAsFixed(3)}, ${entry.longitude.toStringAsFixed(3)}',
                      ),
                      onTap: () => setState(() {
                        final city = entry.toCityClimate(
                          localeCode: _draft.localeCode,
                        );
                        _worldCityQuery.text = city.city;
                        _selectCity(city, saveAsCustom: true);
                      }),
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            LocalizedDropdownButtonFormField<String>(
              initialValue: _selectedCity.isEmpty ? null : _selectedCity,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Город',
                helperText:
                    'Климат и положение солнца заполнятся автоматически',
              ),
              items: [
                for (final city in cityItems)
                  DropdownMenuItem(
                    value: city.city,
                    child: LocalizedText(city.city),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                final city = cityByKey(
                  _selectedCountry,
                  value,
                  extra: customCities,
                );
                if (city == null) {
                  return;
                }
                setState(() => _selectCity(city));
              },
            ),
            const SizedBox(height: 12),
            if (_draft.profile.city.isNotEmpty)
              InfoTile(
                icon: Icons.wb_sunny_outlined,
                title: '${_draft.profile.city}: ${_draft.profile.climate}',
                subtitle:
                    'Лето: ${_draft.profile.climateSummer}\nЗима: ${_draft.profile.climateWinter}\nКоординаты: ${_draft.profile.latitude}, ${_draft.profile.longitude}\n${_draft.profile.solarPhenomena.join(', ')}',
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _searchInlineWorldCities,
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: const LocalizedText('Обновить результаты поиска'),
                  ),
                  TextButton.icon(
                    onPressed: () => _addCustomCity(),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const LocalizedText('Добавить свой город'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in const [
              'низкая активность',
              'умеренная активность',
              'много хожу',
              'тренируюсь 4+ раза',
            ])
              ChoiceChip(
                label: LocalizedText(value),
                selected: _draft.profile.activityLevel == value,
                onSelected: (_) => setState(
                  () => _draft = _draft.copyWith(
                    profile: _draft.profile.copyWith(activityLevel: value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nutritionPrefsStep() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Pill(label: 'учитывать непереносимости'),
            SizedBox(height: 8),
            Pill(label: 'показывать белок в каждом приёме пищи'),
            SizedBox(height: 8),
            Pill(label: 'разрешить фото еды только с подтверждением'),
          ],
        ),
      ),
    );
  }

  Widget _alarmStep() {
    return Card(
      child: SwitchListTile(
        value: _draft.alarmGroups.any((item) => item.adaptive),
        title: const LocalizedText('Адаптивные будильники'),
        subtitle: const LocalizedText(
          'Учитывать сон, поездки и восстановление',
        ),
        onChanged: (value) {
          setState(() {
            final groups = _draft.alarmGroups
                .map(
                  (item) => AlarmGroup(
                    id: item.id,
                    title: item.title,
                    wakeTime: item.wakeTime,
                    bedTime: item.bedTime,
                    days: item.days,
                    adaptive: value,
                  ),
                )
                .toList();
            _draft = _draft.copyWith(alarmGroups: groups);
          });
        },
      ),
    );
  }

  Widget _devicesStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.bluetooth_searching),
              title: LocalizedText('Bluetooth и устройства здоровья'),
              subtitle: LocalizedText(
                'Устройства не выбираются автоматически. Подключение выполняется позже в разделе “Устройства”, где приложение сканирует BLE-устройства и сохраняет их особенности.',
              ),
            ),
            ActionRow(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final device = await editDeviceConnectionDialog(context);
                    if (device == null) {
                      return;
                    }
                    setState(() {
                      _draft = _draft.copyWith(
                        devices: [
                          device,
                          ..._draft.devices.where(
                            (item) =>
                                item.id != device.id &&
                                (device.deviceId.isEmpty ||
                                    item.deviceId != device.deviceId),
                          ),
                        ],
                      );
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const LocalizedText('Добавить устройство'),
                ),
              ],
            ),
            for (final item in _draft.devices)
              SwitchListTile(
                value: item.enabled,
                title: LocalizedText(item.title),
                subtitle: LocalizedText(
                  '${item.type} · ${item.protocol}\n${item.permissions}',
                ),
                secondary: LocalizedIconButton(
                  tooltip: 'Редактировать',
                  onPressed: () async {
                    final updated = await editDeviceConnectionDialog(
                      context,
                      device: item,
                    );
                    if (updated == null) {
                      return;
                    }
                    setState(() {
                      _draft = _draft.copyWith(
                        devices: _draft.devices
                            .map(
                              (candidate) =>
                                  candidate.id == item.id ? updated : candidate,
                            )
                            .toList(),
                      );
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                onChanged: (value) {
                  setState(() {
                    final devices = _draft.devices
                        .map(
                          (candidate) => candidate.id == item.id
                              ? candidate.copyWith(
                                  enabled: value,
                                  lastSync: value
                                      ? 'после настройки'
                                      : 'отключено',
                                )
                              : candidate,
                        )
                        .toList();
                    _draft = _draft.copyWith(devices: devices);
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _privacyStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SwitchListTile(
              value: _draft.settings.encryptedVault,
              title: const LocalizedText('Шифровать локальный сейф'),
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(
                  settings: _draft.settings.copyWith(encryptedVault: value),
                ),
              ),
            ),
            SwitchListTile(
              value: _draft.settings.offlineOnly,
              title: const LocalizedText('Полностью офлайн'),
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(
                  settings: _draft.settings.copyWith(offlineOnly: value),
                ),
              ),
            ),
            SwitchListTile(
              value: _draft.settings.hideLockScreenNotifications,
              title: const LocalizedText('Скрывать чувствительные уведомления'),
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(
                  settings: _draft.settings.copyWith(
                    hideLockScreenNotifications: value,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _motivationStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText('Строгость мотивации'),
            Slider(
              min: 1,
              max: 5,
              divisions: 4,
              value: _draft.settings.motivationStrictness.toDouble(),
              label: '${_draft.settings.motivationStrictness}',
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(
                  settings: _draft.settings.copyWith(
                    motivationStrictness: value.round(),
                  ),
                ),
              ),
            ),
            const MedicalDisclaimerBanner(),
          ],
        ),
      ),
    );
  }

  Widget _onboardingTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LocalizedTextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  Future<void> _addCustomOption({
    required String group,
    required String title,
    required ValueChanged<String> onAdded,
  }) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: LocalizedText('Свой вариант: $title'),
        content: LocalizedTextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название',
            helperText: 'Вариант появится в этом списке и в настройках',
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const LocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                onAdded(value);
              }
              Navigator.pop(dialogContext);
            },
            child: const LocalizedText('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchInlineWorldCities() async {
    final serial = ++_worldCitySearchSerial;
    final query = _worldCityQuery.text.trim();
    setState(() => _worldCityStatus = 'Идёт поиск...');
    final results = await WorldCityDatabase.instance.search(
      query,
      country: _selectedCountry,
      limit: 12,
    );
    if (!mounted || serial != _worldCitySearchSerial) {
      return;
    }
    setState(() {
      _worldCityResults = results;
      _worldCityStatus = results.isEmpty
          ? 'Ничего не найдено, попробуйте другое написание'
          : 'Найдено: ${results.length}';
    });
  }

  void _selectCity(CityClimate city, {bool saveAsCustom = false}) {
    _selectedCountry = city.country;
    _selectedCity = city.city;
    final customOptions = [..._draft.customOptions];
    if (saveAsCustom &&
        !customOptions.any(
          (item) =>
              item.group == 'cities' &&
              item.metadata['country'] == city.country &&
              item.metadata['city'] == city.city,
        )) {
      customOptions.insert(
        0,
        CustomOption(
          id: newId(),
          group: 'cities',
          label: '${city.country} · ${city.city}',
          metadata: {
            'country': city.country,
            'city': city.city,
            'latitude': '${city.latitude}',
            'longitude': '${city.longitude}',
            'climate': city.climate,
            'summer': city.summer,
            'winter': city.winter,
            'phenomena': city.solarPhenomena.join(', '),
          },
        ),
      );
    }
    _draft = _draft.copyWith(
      profile: _draft.profile.copyWith(
        country: city.country,
        city: city.city,
        climate: city.climate,
        climateSummer: city.summer,
        climateWinter: city.winter,
        latitude: city.latitude,
        longitude: city.longitude,
        solarPhenomena: city.solarPhenomena,
      ),
      customOptions: customOptions,
    );
  }

  Future<void> _addCustomCity() async {
    final country = TextEditingController(text: _selectedCountry);
    final city = TextEditingController();
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    final climate = TextEditingController();
    final summer = TextEditingController();
    final winter = TextEditingController();
    final phenomena = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LocalizedText('Свой город'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _onboardingTextField(controller: country, label: 'Страна'),
                _onboardingTextField(controller: city, label: 'Город'),
                _onboardingTextField(
                  controller: latitude,
                  label: 'Широта',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _onboardingTextField(
                  controller: longitude,
                  label: 'Долгота',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _onboardingTextField(controller: climate, label: 'Климат'),
                _onboardingTextField(controller: summer, label: 'Лето'),
                _onboardingTextField(controller: winter, label: 'Зима'),
                _onboardingTextField(
                  controller: phenomena,
                  label: 'Световые явления',
                  hint: 'Например: белые ночи, полярная ночь',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const LocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final countryValue = country.text.trim();
              final cityValue = city.text.trim();
              if (countryValue.isEmpty || cityValue.isEmpty) {
                Navigator.pop(dialogContext);
                return;
              }
              final lat =
                  double.tryParse(latitude.text.replaceAll(',', '.')) ?? 0;
              final lon =
                  double.tryParse(longitude.text.replaceAll(',', '.')) ?? 0;
              final customPhenomena = phenomena.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
              final derived = CityClimate.derived(
                country: countryValue,
                city: cityValue,
                latitude: lat,
                longitude: lon,
                climate: climate.text,
                summer: summer.text,
                winter: winter.text,
                solarPhenomena: customPhenomena,
              );
              setState(() {
                _selectedCountry = countryValue;
                _selectedCity = cityValue;
                _draft = _draft.copyWith(
                  profile: _draft.profile.copyWith(
                    country: countryValue,
                    city: cityValue,
                    latitude: lat,
                    longitude: lon,
                    climate: derived.climate,
                    climateSummer: derived.summer,
                    climateWinter: derived.winter,
                    solarPhenomena: derived.solarPhenomena,
                  ),
                  customOptions: [
                    CustomOption(
                      id: newId(),
                      group: 'cities',
                      label: '$countryValue · $cityValue',
                      metadata: {
                        'country': countryValue,
                        'city': cityValue,
                        'latitude': latitude.text.trim(),
                        'longitude': longitude.text.trim(),
                        'climate': derived.climate,
                        'summer': derived.summer,
                        'winter': derived.winter,
                        'phenomena': derived.solarPhenomena.join(', '),
                      },
                    ),
                    ..._draft.customOptions,
                  ],
                );
              });
              Navigator.pop(dialogContext);
            },
            child: const LocalizedText('Сохранить'),
          ),
        ],
      ),
    );
  }

  List<CityClimate> _customCities() {
    return _draft.customOptions
        .where((item) => item.group == 'cities')
        .map((item) {
          final metadata = item.metadata;
          final country = metadata['country'] ?? '';
          final city = metadata['city'] ?? '';
          if (country.isEmpty || city.isEmpty) {
            return null;
          }
          final latitude = double.tryParse(metadata['latitude'] ?? '') ?? 0;
          final longitude = double.tryParse(metadata['longitude'] ?? '') ?? 0;
          return CityClimate.derived(
            country: country,
            city: city,
            latitude: latitude,
            longitude: longitude,
            climate: metadata['climate'] ?? '',
            summer: metadata['summer'] ?? '',
            winter: metadata['winter'] ?? '',
            solarPhenomena: (metadata['phenomena'] ?? '')
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
          );
        })
        .whereType<CityClimate>()
        .toList();
  }

  HealthAppState _commitControllers(HealthAppState state) {
    return state.copyWith(
      profile: state.profile.copyWith(
        name: _name.text.trim().isEmpty
            ? state.profile.name
            : _name.text.trim(),
        birthDate: dateStorageText(
          _birthDate.text,
          fallback: state.profile.birthDate,
        ),
        heightCm:
            double.tryParse(_height.text.trim().replaceAll(',', '.')) ??
            state.profile.heightCm,
        weightKg:
            double.tryParse(_weight.text.trim().replaceAll(',', '.')) ??
            state.profile.weightKg,
        goal: _committedGoal(state.profile.goal),
        trainingGoals: _committedGoals(),
      ),
      today: state.today.copyWith(
        weightKg:
            double.tryParse(_weight.text.trim().replaceAll(',', '.')) ??
            state.today.weightKg,
      ),
    );
  }

  List<String> _committedGoals() {
    final custom = _goal.text.trim();
    if (custom.isNotEmpty) return [custom];
    return _trainingGoals.take(1).toList();
  }

  String _committedGoal(String fallback) {
    final goals = _committedGoals();
    return goals.isEmpty ? fallback : goals.join(', ');
  }
}

class _WorldCityPickerDialog extends StatefulWidget {
  const _WorldCityPickerDialog();

  @override
  State<_WorldCityPickerDialog> createState() => _WorldCityPickerDialogState();
}

class _WorldCityPickerDialogState extends State<_WorldCityPickerDialog> {
  static const _allCountries = '__all_countries__';

  final _query = TextEditingController();
  List<String> _countries = const [];
  List<WorldCityEntry> _results = const [];
  String _selectedCountry = _allCountries;
  bool _loading = true;
  String _status = 'Загрузка мировой базы городов...';
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _loadCountriesAndSearch();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadCountriesAndSearch() async {
    final countries = await WorldCityDatabase.instance.countries();
    if (!mounted) {
      return;
    }
    setState(() => _countries = countries);
    await _runSearch('');
  }

  Future<void> _runSearch(String query) async {
    final serial = ++_serial;
    final country = _selectedCountry == _allCountries ? '' : _selectedCountry;
    setState(() {
      _loading = true;
      if (query.trim().isEmpty) {
        _status = country.isEmpty
            ? 'Загрузка крупнейших городов...'
            : 'Города страны: $country';
      } else {
        _status = country.isEmpty
            ? 'Поиск "$query"...'
            : 'Поиск "$query" в стране $country...';
      }
    });
    final results = country.isEmpty
        ? await WorldCityDatabase.instance.search(query, limit: 40)
        : await WorldCityDatabase.instance.citiesByCountry(
            country,
            query: query,
            limit: 80,
          );
    if (!mounted || serial != _serial) {
      return;
    }
    setState(() {
      _results = results;
      _loading = false;
      _status = results.isEmpty
          ? 'Город не найден. Попробуйте латиницу, местное название или страну.'
          : country.isEmpty
          ? 'Найдено ${results.length} вариантов'
          : 'Найдено ${results.length} городов · $country';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const LocalizedText('Мировая база городов'),
      content: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          children: [
            LocalizedDropdownButtonFormField<String>(
              key: ValueKey(_selectedCountry),
              initialValue: _selectedCountry,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.public_outlined),
                labelText: 'Страна',
                helperText: 'Список стран загружается из GeoNames офлайн',
              ),
              items: [
                const DropdownMenuItem(
                  value: _allCountries,
                  child: LocalizedText('Все страны'),
                ),
                for (final country in _countries)
                  DropdownMenuItem(
                    value: country,
                    child: LocalizedText(country),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedCountry = value);
                _runSearch(_query.text);
              },
            ),
            const SizedBox(height: 10),
            LocalizedTextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Город',
                hintText: 'Например: Murmansk, Saint Petersburg, Tokyo',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              onChanged: (value) {
                if (value.trim().isEmpty || value.trim().length >= 2) {
                  _runSearch(value);
                }
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_loading) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: LocalizedText(_status)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final city = _results[index];
                  final climate = city.toCityClimate();
                  final profile = climateProfileFor(city.latitude);
                  return ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: LocalizedText('${city.city}, ${city.country}'),
                    subtitle: LocalizedText(
                      'Население ${city.population} · ${city.latitude.toStringAsFixed(3)}, ${city.longitude.toStringAsFixed(3)} · ${city.timezone}\n${profile.solarPhenomena.join(', ')} · день ${profile.shortestDay}-${profile.longestDay}',
                    ),
                    onTap: () => Navigator.pop(context, climate),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LocalizedText('Отмена'),
        ),
      ],
    );
  }
}

extension on NavigationDrawerDestination {
  Widget asListTile(
    BuildContext context, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: selected ? selectedIcon : icon,
        title: label,
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

ThemeData _theme(Brightness brightness, bool highContrast, double uiScale) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: brightness,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF111715)
        : const Color(0xFFF6F8F7),
    visualDensity: VisualDensity.standard,
  );
  final radius = BorderRadius.circular(8 * uiScale);
  return base.copyWith(
    dividerColor: highContrast ? scheme.outline : scheme.outlineVariant,
    iconTheme: IconThemeData(size: 24 * uiScale),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 4 * uiScale,
      contentPadding: EdgeInsets.symmetric(horizontal: 16 * uiScale),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(64 * uiScale, 40 * uiScale),
        padding: EdgeInsets.symmetric(
          horizontal: 16 * uiScale,
          vertical: 10 * uiScale,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(64 * uiScale, 40 * uiScale),
        padding: EdgeInsets.symmetric(
          horizontal: 16 * uiScale,
          vertical: 10 * uiScale,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
      filled: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      contentPadding: EdgeInsets.fromLTRB(
        14 * uiScale,
        18 * uiScale,
        14 * uiScale,
        14 * uiScale,
      ),
    ),
  );
}

ThemeMode _themeMode(String value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
