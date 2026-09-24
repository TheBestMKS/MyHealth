part of '../screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'settings'),
      subtitle: 'Язык, внешний вид, приватность, AI и доступность',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Язык',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LocalizedDropdownButtonFormField<String>(
                  initialValue: state.localeCode,
                  items: [
                    for (final language in supportedLanguages)
                      DropdownMenuItem(
                        value: language.code,
                        child: Text(
                          '${language.nativeName} · ${language.englishName}',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(state.copyWith(localeCode: value));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        _CapabilityCenter(state: state),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Языки содержимого',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _settingsChoice(
                  label: 'Язык рецептов',
                  value: state.profile.recipeLanguage,
                  options: const {
                    'system': 'как интерфейс',
                    'ru': 'русский',
                    'en': 'English',
                  },
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      profile: state.profile.copyWith(recipeLanguage: value),
                    ),
                  ),
                ),
                _settingsChoice(
                  label: 'Язык тренировок',
                  value: state.profile.workoutLanguage,
                  options: const {
                    'system': 'как интерфейс',
                    'ru': 'русский',
                    'en': 'English',
                  },
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      profile: state.profile.copyWith(workoutLanguage: value),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Единицы и форматы',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _settingsChoice(
                  label: 'Система мер',
                  value: state.settings.unitSystem,
                  options: const {
                    'metric': 'метрическая',
                    'imperial': 'английская',
                    'mixed': 'смешанная',
                  },
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(unitSystem: value),
                    ),
                  ),
                ),
                _settingsChoice(
                  label: 'Рост',
                  value: state.settings.heightUnit,
                  options: const {'cm': 'сантиметры', 'ft': 'футы и дюймы'},
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(heightUnit: value),
                    ),
                  ),
                ),
                _settingsChoice(
                  label: 'Формат даты',
                  value: state.settings.dateDisplayFormat,
                  options: const {
                    'dd.mm.yyyy': 'ДД.ММ.ГГГГ',
                    'dd/mm/yyyy': 'ДД/ММ/ГГГГ',
                    'mm/dd/yyyy': 'ММ/ДД/ГГГГ',
                  },
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(
                        dateDisplayFormat: value,
                      ),
                    ),
                  ),
                ),
                _settingsChoice(
                  label: 'Формат времени',
                  value: state.settings.timeFormat,
                  options: const {'24h': '24 часа', '12h': '12 часов'},
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(timeFormat: value),
                    ),
                  ),
                ),
                _settingsChoice(
                  label: 'Расстояние',
                  value: state.settings.distanceUnit,
                  options: const {'km': 'километры', 'mi': 'мили'},
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(distanceUnit: value),
                    ),
                  ),
                ),
                _settingsChoice(
                  label: 'Вес',
                  value: state.settings.bodyWeightUnit,
                  options: const {'kg': 'килограммы', 'lb': 'фунты'},
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(bodyWeightUnit: value),
                    ),
                  ),
                ),
                _settingsChoice(
                  label: 'Температура',
                  value: state.settings.temperatureUnit,
                  options: const {'celsius': '°C', 'fahrenheit': '°F'},
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(temperatureUnit: value),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Уведомления',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _switchTile(
                  title: 'Системные уведомления',
                  subtitle: 'Напоминания работают после закрытия приложения',
                  value: state.settings.notificationsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      await HealthNotificationService.instance
                          .requestPermissions();
                    }
                    onChanged(
                      state.copyWith(
                        settings: state.settings.copyWith(
                          notificationsEnabled: value,
                        ),
                      ),
                    );
                  },
                ),
                _switchTile(
                  title: 'Лекарства и остаток',
                  subtitle: 'Расписание приёма и напоминание о покупке',
                  value: state.settings.medicationNotifications,
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(
                        medicationNotifications: value,
                      ),
                    ),
                  ),
                ),
                _switchTile(
                  title: 'Разминка и вода',
                  subtitle: 'Интервалы и тихие часы берутся из профиля',
                  value: state.settings.activityNotifications,
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(
                        activityNotifications: value,
                      ),
                    ),
                  ),
                ),
                _switchTile(
                  title: 'Будильники',
                  subtitle: 'Учитываются работа, дежурства, отпуск и поездки',
                  value: state.settings.alarmNotifications,
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(
                        alarmNotifications: value,
                      ),
                    ),
                  ),
                ),
                _switchTile(
                  title: 'Фоновый анализ',
                  subtitle:
                      'Периодически проверять локальные напоминания и расписание без отправки данных в сеть',
                  value: state.settings.backgroundAnalysisEnabled,
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(
                        backgroundAnalysisEnabled: value,
                      ),
                    ),
                  ),
                ),
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                  _switchTile(
                    title: 'Автозапуск вместе с системой',
                    subtitle:
                        'Запускать приложение после входа в систему для локального фонового анализа',
                    value: state.settings.launchAtStartup,
                    onChanged: (value) => onChanged(
                      state.copyWith(
                        settings: state.settings.copyWith(
                          launchAtStartup: value,
                        ),
                      ),
                    ),
                  ),
                FutureBuilder<int>(
                  future: HealthNotificationService.instance.pendingCount(),
                  builder: (context, snapshot) => InfoTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Запланировано уведомлений: ${snapshot.data ?? 0}',
                    subtitle:
                        HealthNotificationService.instance.lastError.isEmpty
                        ? 'Нажмите, чтобы показать проверочное уведомление.'
                        : 'Ошибка: ${HealthNotificationService.instance.lastError}',
                    onTap: () async {
                      await HealthNotificationService.instance
                          .requestPermissions();
                      await HealthNotificationService.instance.showTest();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Внешний вид',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _settingsChoice(
                  label: 'Тема',
                  value: state.settings.themeMode,
                  options: const {
                    'system': 'системная',
                    'light': 'светлая',
                    'dark': 'тёмная',
                  },
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(themeMode: value),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _switchTile(
          title: 'Расширенный интерфейс',
          subtitle: 'Больше аналитики, таблиц и быстрых действий',
          value: state.settings.advancedMode,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(advancedMode: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Компактный интерфейс',
          subtitle:
              'Уменьшает отступы и группирует действия, сохраняя удобные области нажатия',
          value: state.settings.compactMode,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(compactMode: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Крупный шрифт',
          subtitle: 'Повышает масштаб интерфейса',
          value: state.settings.largeText,
          onChanged: (value) => onChanged(
            state.copyWith(settings: state.settings.copyWith(largeText: value)),
          ),
        ),
        _switchTile(
          title: 'Высокая контрастность',
          subtitle: 'Усиливает границы и контраст карточек',
          value: state.settings.highContrast,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(highContrast: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Локальный AI-анализ',
          subtitle: 'Все выводы помечаются как предположительные',
          value: state.settings.aiEnabled,
          onChanged: (value) => onChanged(
            state.copyWith(settings: state.settings.copyWith(aiEnabled: value)),
          ),
        ),
        _switchTile(
          title: 'Требовать подтверждение распознавания',
          subtitle:
              'Фото еды, OCR анализов и документы не применяются автоматически',
          value: state.settings.requireRecognitionConfirmation,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(
                requireRecognitionConfirmation: value,
              ),
            ),
          ),
        ),
        _switchTile(
          title: 'Шифрованный локальный сейф',
          subtitle: 'Данные сохраняются локально через AES-GCM',
          value: state.settings.encryptedVault,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(encryptedVault: value),
            ),
          ),
        ),
        _switchTile(
          title: 'PIN-код',
          subtitle: 'Блокировать медицинский раздел отдельным кодом',
          value: state.settings.pinEnabled,
          onChanged: (value) =>
              _configurePin(context, state, onChanged, enable: value),
        ),
        _switchTile(
          title: 'Отдельная защита документов',
          subtitle:
              'Повторно запрашивать PIN или биометрию для чувствительных документов',
          value: state.settings.medicalLock,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(medicalLock: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Биометрия',
          subtitle: 'Разрешить системную биометрическую разблокировку',
          value: state.settings.biometricEnabled,
          onChanged: (value) async {
            if (value && !state.settings.pinEnabled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: LocalizedText('Сначала установите PIN-код.'),
                ),
              );
              return;
            }
            if (value &&
                !await SecurityService.instance.authenticateBiometric()) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: LocalizedText(
                      'Системная биометрия недоступна или отменена.',
                    ),
                  ),
                );
              }
              return;
            }
            onChanged(
              state.copyWith(
                settings: state.settings.copyWith(biometricEnabled: value),
              ),
            );
          },
        ),
        _switchTile(
          title: 'Скрывать медицинские уведомления',
          subtitle: 'Не показывать чувствительный текст на экране блокировки',
          value: state.settings.hideLockScreenNotifications,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(
                hideLockScreenNotifications: value,
              ),
            ),
          ),
        ),
        _switchTile(
          title: 'Полностью офлайн',
          subtitle:
              'Синхронизация и облако выключены, пока пользователь не разрешит',
          value: state.settings.offlineOnly,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(offlineOnly: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Подтверждать выход',
          subtitle:
              'Спрашивать перед закрытием; сворачивание приложения остаётся без подтверждения',
          value: state.settings.confirmBeforeExit,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(confirmBeforeExit: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Геолокация для тренировок',
          subtitle:
              'Бег, ходьба и велосипед считают маршрут, скорость и дистанцию',
          value: state.settings.geolocationEnabled,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(geolocationEnabled: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Карты OpenStreetMap',
          subtitle: 'Показывать карту маршрута во время геотренировки',
          value: state.settings.openStreetMapEnabled,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(openStreetMapEnabled: value),
            ),
          ),
        ),
        _switchTile(
          title: 'Загрузка офлайн-карт',
          subtitle:
              'Разрешает скачивание векторного пакета города, региона или страны',
          value: state.settings.offlineMapDownloadEnabled,
          onChanged: (value) => onChanged(
            state.copyWith(
              settings: state.settings.copyWith(
                offlineMapDownloadEnabled: value,
              ),
            ),
          ),
        ),
        InfoTile(
          icon: Icons.map_outlined,
          title: 'Офлайн-карты',
          subtitle: state.offlineMapPacks.isEmpty
              ? 'Нет загруженных пакетов. Используется город из профиля.'
              : '${state.offlineMapPacks.length} пакетов: ${state.offlineMapPacks.map((item) => item.title).take(2).join(', ')}',
          onTap: () => _downloadOfflineMapPack(context, state, onChanged),
        ),
        ...state.offlineMapPacks
            .take(4)
            .map(
              (pack) => InfoTile(
                icon: Icons.map,
                title: pack.title,
                subtitle:
                    '${pack.scope} · ${pack.format.toUpperCase()} · zoom ${pack.minZoom}-${pack.maxZoom} · ${pack.tileCount} тайлов\n${pack.storagePath}',
                onLongPress: () => _confirmDelete(
                  context,
                  title: pack.title,
                  onDelete: () {
                    unawaited(OfflineMapService().deletePack(pack));
                    onChanged(
                      state.copyWith(
                        offlineMapPacks: state.offlineMapPacks
                            .where((item) => item.id != pack.id)
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
        const SectionTitle('Диагностика'),
        InfoTile(
          icon: Icons.article_outlined,
          title: 'Журнал ошибок',
          subtitle:
              'Ошибки Flutter, фоновых задач, уведомлений и запуска сохраняются только на этом устройстве.',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showErrorLogDialog(context),
        ),
        const SectionTitle('Резервные копии и перенос данных'),
        InfoTile(
          icon: Icons.backup_outlined,
          title: 'Создать резервную копию JSON',
          subtitle:
              'Полная копия профиля, дневников, медкарты, расписания и настроек в папке документов.',
          onTap: () => _exportBackup(context, state),
        ),
        InfoTile(
          icon: Icons.table_view_outlined,
          title: 'Экспортировать таблицы CSV',
          subtitle:
              'Отдельные UTF-8 таблицы питания, тренировок и анализов для Excel или другого приложения.',
          onTap: () => _exportCsvTables(context, state),
        ),
        InfoTile(
          icon: Icons.restore_page_outlined,
          title: 'Восстановить из JSON',
          subtitle:
              'Перед заменой текущих данных файл проверяется, затем требуется подтверждение.',
          onTap: () => _importBackup(context, state, onChanged),
        ),
        InfoTile(
          icon: Icons.delete_forever_outlined,
          title: 'Удалить все локальные данные',
          subtitle:
              'Безвозвратно очищает профиль, медкарту, дневники и настройки на этом устройстве.',
          onTap: () => _resetAllData(context, state, onChanged),
        ),
        InfoTile(
          icon: Icons.tune_outlined,
          title: 'Пользовательские варианты',
          subtitle: state.customOptions.isEmpty
              ? 'Пока нет добавленных вручную вариантов'
              : '${state.customOptions.length} вариантов: ${state.customOptions.map((item) => item.label).take(3).join(', ')}',
          onTap: () => _showCustomOptionsManager(context, state, onChanged),
        ),
        InfoTile(
          icon: Icons.info_outline,
          title: 'О программе',
          subtitle:
              'Версия 1.8.1+10 · создатель: Редин Максим Юрьевич · info@thebestmks.ru',
          onTap: () => _showAboutProgram(context),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Масштаб интерфейса',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  label: '${(state.settings.uiScale * 100).round()}%',
                  value: state.settings.uiScale,
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(uiScale: value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LocalizedText(
                  'Строгость мотивации',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  min: 1,
                  max: 4,
                  divisions: 3,
                  label: const {
                    1: 'мягкий',
                    2: 'обычный',
                    3: 'строгий',
                    4: 'агрессивный',
                  }[state.settings.motivationStrictness.clamp(1, 4)],
                  value: state.settings.motivationStrictness
                      .clamp(1, 4)
                      .toDouble(),
                  onChanged: (value) => onChanged(
                    state.copyWith(
                      settings: state.settings.copyWith(
                        motivationStrictness: value.round(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CapabilityCenter extends StatefulWidget {
  const _CapabilityCenter({required this.state});

  final HealthAppState state;

  @override
  State<_CapabilityCenter> createState() => _CapabilityCenterState();
}

class _CapabilityCenterState extends State<_CapabilityCenter> {
  late Future<_CapabilitySnapshot> _future = _load();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const SizedBox(width: 9),
                Expanded(
                  child: LocalizedText(
                    'Возможности и разрешения',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                LocalizedIconButton(
                  tooltip: 'Проверить снова',
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            FutureBuilder<_CapabilitySnapshot>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }
                final data = snapshot.data!;
                return Column(
                  children: [
                    for (final permission in data.permissions)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(permission.icon),
                        title: LocalizedText(permission.title),
                        subtitle: LocalizedText(permission.statusText),
                        trailing: permission.permission == null
                            ? const Icon(Icons.check_circle_outline)
                            : LocalizedIconButton(
                                tooltip: 'Запросить разрешение повторно',
                                onPressed: () =>
                                    _request(permission.permission!),
                                icon: const Icon(Icons.refresh),
                              ),
                      ),
                    const Divider(),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.memory_outlined),
                      title: const LocalizedText('Локальная языковая модель'),
                      subtitle: LocalizedText(
                        data.model.isInstalled
                            ? '${data.model.name} · ${data.model.sizeLabel} · ${data.model.isMultimodal ? 'vision включён' : 'только текст'} · ${data.model.isBundled ? 'Full' : 'импорт/загрузка'}'
                            : 'Не установлена; доступен быстрый режим и установка в разделе «Помощник».',
                      ),
                      trailing: Icon(
                        data.model.isInstalled
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.health_and_safety_outlined),
                      title: LocalizedText(data.health.provider),
                      subtitle: LocalizedText(data.health.message),
                      trailing: data.health.supported
                          ? const Icon(Icons.check_circle_outline)
                          : const Icon(Icons.info_outline),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.autorenew_outlined),
                      title: const LocalizedText('Фоновая работа'),
                      subtitle: LocalizedText(
                        '${data.runtime.backgroundScheduled ? 'задача запланирована' : 'задача не запланирована'}'
                        '${data.runtime.lastBackgroundRun == null ? '' : ' · последняя проверка ${_compactDateTime(data.runtime.lastBackgroundRun!.toIso8601String())}'}'
                        '${data.runtime.lastBackgroundResult.isEmpty ? '' : '\n${data.runtime.lastBackgroundResult}'}',
                      ),
                      trailing: Icon(
                        data.runtime.backgroundScheduled
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                      ),
                    ),
                    if (AppRuntimeService.instance.supportsDesktopStartup)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.power_settings_new_outlined),
                        title: const LocalizedText('Автозапуск'),
                        subtitle: LocalizedText(
                          data.runtime.launchAtStartupEnabled
                              ? 'Включён в системном профиле пользователя'
                              : 'Выключен',
                        ),
                      ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_outlined),
                      title: const LocalizedText('Системные уведомления'),
                      subtitle: LocalizedText(
                        'Запланировано: ${data.pendingNotifications}',
                      ),
                      trailing: LocalizedIconButton(
                        tooltip: 'Проверить уведомление',
                        onPressed: () async {
                          await HealthNotificationService.instance
                              .requestPermissions();
                          await HealthNotificationService.instance.showTest();
                          if (mounted) setState(() => _future = _load());
                        },
                        icon: const Icon(Icons.notification_add_outlined),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: openAppSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const LocalizedText(
                          'Системные настройки доступа',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _request(Permission permission) async {
    await permission.request();
    if (mounted) setState(() => _future = _load());
  }

  Future<_CapabilitySnapshot> _load() async {
    final permissions = <_PermissionCapability>[];
    if (Platform.isAndroid || Platform.isIOS) {
      final definitions = <(String, IconData, Permission)>[
        ('Камера', Icons.photo_camera_outlined, Permission.camera),
        (
          'Микрофон и голосовой ввод',
          Icons.mic_none_outlined,
          Permission.microphone,
        ),
        (
          'Геолокация',
          Icons.location_on_outlined,
          Permission.locationWhenInUse,
        ),
        ('Уведомления', Icons.notifications_outlined, Permission.notification),
        (
          'Физическая активность',
          Icons.directions_walk_outlined,
          Permission.activityRecognition,
        ),
        if (Platform.isAndroid)
          (
            'Bluetooth: поиск устройств',
            Icons.bluetooth_outlined,
            Permission.bluetoothScan,
          ),
        if (Platform.isAndroid)
          (
            'Bluetooth: подключение',
            Icons.bluetooth_connected_outlined,
            Permission.bluetoothConnect,
          ),
        if (Platform.isAndroid)
          (
            'Точные будильники',
            Icons.alarm_outlined,
            Permission.scheduleExactAlarm,
          ),
      ];
      for (final definition in definitions) {
        PermissionStatus status;
        try {
          status = await definition.$3.status;
        } catch (_) {
          status = PermissionStatus.denied;
        }
        permissions.add(
          _PermissionCapability(
            title: definition.$1,
            icon: definition.$2,
            permission: definition.$3,
            statusText: _permissionStatusText(status),
          ),
        );
      }
    } else {
      permissions.addAll(const [
        _PermissionCapability(
          title: 'Камера и микрофон',
          icon: Icons.perm_camera_mic_outlined,
          statusText:
              'Доступ запрашивается операционной системой при использовании.',
        ),
        _PermissionCapability(
          title: 'Файлы',
          icon: Icons.folder_open_outlined,
          statusText: 'Доступ только к файлам, которые выбрал пользователь.',
        ),
      ]);
    }
    HealthPlatformAvailability health;
    try {
      health = await HealthPlatformService().checkAvailability();
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Health capability check',
      );
      health = HealthPlatformAvailability(
        supported: false,
        provider: 'Health Connect / Apple Health',
        message: 'Проверка недоступна: ${_shortAssistantError(error)}',
      );
    }
    return _CapabilitySnapshot(
      permissions: permissions,
      model: await LocalLlmService.instance.status(),
      health: health,
      runtime: await AppRuntimeService.instance.status(),
      pendingNotifications: await HealthNotificationService.instance
          .pendingCount(),
    );
  }
}

class _PermissionCapability {
  const _PermissionCapability({
    required this.title,
    required this.icon,
    required this.statusText,
    this.permission,
  });

  final String title;
  final IconData icon;
  final String statusText;
  final Permission? permission;
}

class _CapabilitySnapshot {
  const _CapabilitySnapshot({
    required this.permissions,
    required this.model,
    required this.health,
    required this.runtime,
    required this.pendingNotifications,
  });

  final List<_PermissionCapability> permissions;
  final LocalModelStatus model;
  final HealthPlatformAvailability health;
  final RuntimeStatus runtime;
  final int pendingNotifications;
}

String _permissionStatusText(PermissionStatus status) {
  if (status.isGranted || status.isLimited || status.isProvisional) {
    return 'Разрешено';
  }
  if (status.isPermanentlyDenied || status.isRestricted) {
    return 'Запрещено системой; откройте системные настройки';
  }
  return 'Не разрешено; нажмите для повторного запроса';
}

Future<void> _exportBackup(BuildContext context, HealthAppState state) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await BackupService().exportJson(state);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: LocalizedText('Резервная копия создана: ${file.path}')),
    );
  } catch (error, stackTrace) {
    await ErrorLogService.instance.recordError(
      error,
      stackTrace,
      source: 'JSON backup export',
    );
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: LocalizedText('Не удалось создать копию: $error')),
      );
    }
  }
}

Future<void> _exportCsvTables(
  BuildContext context,
  HealthAppState state,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final files = await BackupService().exportCsvTables(state);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: LocalizedText(
          'Создано ${files.length} CSV-файла. Папка: ${files.first.parent.path}',
        ),
      ),
    );
  } catch (error, stackTrace) {
    await ErrorLogService.instance.recordError(
      error,
      stackTrace,
      source: 'CSV export',
    );
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: LocalizedText('Не удалось экспортировать CSV: $error'),
        ),
      );
    }
  }
}

Future<void> _importBackup(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final imported = await BackupService().importJson();
    if (imported == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LocalizedText('Восстановить резервную копию?'),
        content: LocalizedText(
          'Текущий профиль «${state.profile.name}» будет заменён профилем '
          '«${imported.profile.name}». Перед продолжением рекомендуется сделать копию текущих данных.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LocalizedText('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onChanged(imported);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: LocalizedText('Резервная копия восстановлена.'),
          ),
        );
      }
    }
  } catch (error, stackTrace) {
    await ErrorLogService.instance.recordError(
      error,
      stackTrace,
      source: 'JSON backup import',
    );
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: LocalizedText('Не удалось восстановить копию: $error'),
        ),
      );
    }
  }
}

Future<void> _resetAllData(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final controller = TextEditingController();
  var error = '';
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const LocalizedText('Удалить все локальные данные?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LocalizedText(
              'Операцию нельзя отменить без ранее созданной резервной копии. Введите УДАЛИТЬ для подтверждения.',
            ),
            const SizedBox(height: 12),
            LocalizedTextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Подтверждение',
                errorText: error.isEmpty ? null : error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim() != 'УДАЛИТЬ') {
                setDialogState(() => error = 'Введите слово УДАЛИТЬ полностью');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const LocalizedText('Удалить данные'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (confirmed == true) {
    await DocumentVaultService.instance.clearVault();
    onChanged(HealthAppState.seed());
  }
}

Future<void> _configurePin(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, {
  required bool enable,
}) async {
  final pin = TextEditingController();
  final confirm = TextEditingController();
  var error = '';
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: LocalizedText(
          enable ? 'Установить PIN-код' : 'Отключить PIN-код',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LocalizedTextField(
                controller: pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: enable
                      ? 'Новый PIN, минимум 4 цифры'
                      : 'Текущий PIN',
                  errorText: error.isEmpty ? null : error,
                ),
              ),
              if (enable)
                LocalizedTextField(
                  controller: confirm,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: const InputDecoration(labelText: 'Повторите PIN'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (enable) {
                if (!RegExp(r'^\d{4,12}$').hasMatch(pin.text)) {
                  setDialogState(() => error = 'Введите от 4 до 12 цифр');
                  return;
                }
                if (pin.text != confirm.text) {
                  setDialogState(() => error = 'PIN-коды не совпадают');
                  return;
                }
              } else {
                final valid = await SecurityService.instance.verifyPin(
                  pin.text,
                  state.settings.pinHash,
                  state.settings.pinSalt,
                );
                if (!valid) {
                  setDialogState(() => error = 'Неверный PIN-код');
                  return;
                }
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const LocalizedText('Подтвердить'),
          ),
        ],
      ),
    ),
  );
  if (accepted != true) return;
  if (enable) {
    final credential = await SecurityService.instance.createPin(pin.text);
    onChanged(
      state.copyWith(
        settings: state.settings.copyWith(
          pinEnabled: true,
          pinHash: credential.hash,
          pinSalt: credential.salt,
        ),
      ),
    );
  } else {
    onChanged(
      state.copyWith(
        settings: state.settings.copyWith(
          pinEnabled: false,
          biometricEnabled: false,
          pinHash: '',
          pinSalt: '',
        ),
      ),
    );
  }
}

Widget _numberField(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: LocalizedTextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    ),
  );
}

Future<void> _downloadOfflineMapPack(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  var scope = 'city';
  var running = false;
  var status = '';
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const LocalizedText('Загрузить офлайн-карту'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LocalizedDropdownButtonFormField<String>(
                initialValue: scope,
                decoration: const InputDecoration(labelText: 'Область'),
                items: const [
                  DropdownMenuItem(
                    value: 'city',
                    child: LocalizedText('город'),
                  ),
                  DropdownMenuItem(
                    value: 'region',
                    child: LocalizedText('регион'),
                  ),
                  DropdownMenuItem(
                    value: 'country',
                    child: LocalizedText('страна'),
                  ),
                ],
                onChanged: running
                    ? null
                    : (value) {
                        if (value != null) {
                          setDialogState(() => scope = value);
                        }
                      },
              ),
              const SizedBox(height: 10),
              LocalizedText(
                'Локация профиля: ${state.profile.country} · ${state.profile.city}\nКоординаты: ${state.profile.latitude}, ${state.profile.longitude}',
              ),
              const SizedBox(height: 8),
              const LocalizedText(
                'Векторная карта Protomaps на основе OpenStreetMap сохраняется только для выбранной области.',
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 10),
                LocalizedText(status),
              ],
              if (running) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: running ? null : () => Navigator.pop(dialogContext),
            child: const LocalizedText('Закрыть'),
          ),
          FilledButton.icon(
            onPressed:
                running ||
                    !state.settings.offlineMapDownloadEnabled ||
                    state.settings.offlineOnly
                ? null
                : () async {
                    setDialogState(() {
                      running = true;
                      status = 'Скачиваем векторный пакет карты...';
                    });
                    try {
                      final result = await OfflineMapService()
                          .downloadAroundProfile(
                            profile: state.profile,
                            scope: scope,
                            onProgress: (completed, total) {
                              if (!dialogContext.mounted) return;
                              setDialogState(
                                () => status =
                                    'Сохранено и проверено $completed из $total тайлов...',
                              );
                            },
                          );
                      onChanged(
                        state.copyWith(
                          offlineMapPacks: [
                            result.pack,
                            ...state.offlineMapPacks,
                          ],
                        ),
                      );
                      setDialogState(() {
                        running = false;
                        status =
                            'Готово: сохранено ${result.downloaded}, пустых тайлов ${result.skipped}.';
                      });
                    } catch (error, stackTrace) {
                      await ErrorLogService.instance.recordError(
                        error,
                        stackTrace,
                        source: 'Offline map download',
                      );
                      setDialogState(() {
                        running = false;
                        status = 'Не удалось загрузить карту: $error';
                      });
                    }
                  },
            icon: const Icon(Icons.download_outlined),
            label: const LocalizedText('Загрузить'),
          ),
        ],
      ),
    ),
  );
}

VideoPlayerController? _activeCatalogVideoController;
