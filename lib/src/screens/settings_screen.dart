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
                Text('Язык', style: Theme.of(context).textTheme.titleMedium),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                Text(
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
                Text(
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
                Text(
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
                const SnackBar(content: Text('Сначала установите PIN-код.')),
              );
              return;
            }
            if (value &&
                !await SecurityService.instance.authenticateBiometric()) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
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
          subtitle: 'Разрешает скачивание тайлов города, региона или страны',
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
                    '${pack.scope} · zoom ${pack.minZoom}-${pack.maxZoom} · ${pack.tileCount} тайлов\n${pack.storagePath}',
                onLongPress: () => _confirmDelete(
                  context,
                  title: pack.title,
                  onDelete: () => onChanged(
                    state.copyWith(
                      offlineMapPacks: state.offlineMapPacks
                          .where((item) => item.id != pack.id)
                          .toList(),
                    ),
                  ),
                ),
              ),
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
              'Версия 1.6.0+7 · создатель: Редин Максим Юрьевич · info@thebestmks.ru',
          onTap: () => _showAboutProgram(context),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                Text(
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

Future<void> _exportBackup(BuildContext context, HealthAppState state) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await BackupService().exportJson(state);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Резервная копия создана: ${file.path}')),
    );
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось создать копию: $error')),
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
        content: Text(
          'Создано ${files.length} CSV-файла. Папка: ${files.first.parent.path}',
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать CSV: $error')),
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
        title: const Text('Восстановить резервную копию?'),
        content: Text(
          'Текущий профиль «${state.profile.name}» будет заменён профилем '
          '«${imported.profile.name}». Перед продолжением рекомендуется сделать копию текущих данных.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onChanged(imported);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Резервная копия восстановлена.')),
        );
      }
    }
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось восстановить копию: $error')),
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
        title: const Text('Удалить все локальные данные?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
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
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim() != 'УДАЛИТЬ') {
                setDialogState(() => error = 'Введите слово УДАЛИТЬ полностью');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Удалить данные'),
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
        title: Text(enable ? 'Установить PIN-код' : 'Отключить PIN-код'),
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
            child: const Text('Отмена'),
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
            child: const Text('Подтвердить'),
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
        title: const Text('Загрузить офлайн-карту'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LocalizedDropdownButtonFormField<String>(
                initialValue: scope,
                decoration: const InputDecoration(labelText: 'Область'),
                items: const [
                  DropdownMenuItem(value: 'city', child: Text('город')),
                  DropdownMenuItem(value: 'region', child: Text('регион')),
                  DropdownMenuItem(value: 'country', child: Text('страна')),
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
              Text(
                'Локация профиля: ${state.profile.country} · ${state.profile.city}\nКоординаты: ${state.profile.latitude}, ${state.profile.longitude}',
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(status),
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
            child: const Text('Закрыть'),
          ),
          FilledButton.icon(
            onPressed: running || !state.settings.offlineMapDownloadEnabled
                ? null
                : () async {
                    setDialogState(() {
                      running = true;
                      status = 'Скачиваем тайлы OpenStreetMap...';
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
                                    'Скачано и проверено $completed из $total тайлов...',
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
                            'Готово: скачано ${result.downloaded}, уже было/пропущено ${result.skipped}.';
                      });
                    } catch (error) {
                      setDialogState(() {
                        running = false;
                        status = 'Не удалось загрузить карту: $error';
                      });
                    }
                  },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Загрузить'),
          ),
        ],
      ),
    ),
  );
}

VideoPlayerController? _activeCatalogVideoController;
