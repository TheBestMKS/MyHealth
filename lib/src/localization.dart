import 'package:flutter/material.dart';

import 'generated_ui_translations.dart';

class SupportedLanguage {
  const SupportedLanguage(this.code, this.nativeName, this.englishName);

  final String code;
  final String nativeName;
  final String englishName;
}

const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage('ru', 'Русский', 'Russian'),
  SupportedLanguage('en', 'English', 'English'),
  SupportedLanguage('zh', '中文', 'Chinese'),
  SupportedLanguage('ja', '日本語', 'Japanese'),
  SupportedLanguage('be', 'Беларуская', 'Belarusian'),
  SupportedLanguage('kk', 'Қазақша', 'Kazakh'),
  SupportedLanguage('de', 'Deutsch', 'German'),
  SupportedLanguage('fr', 'Français', 'French'),
  SupportedLanguage('es', 'Español', 'Spanish'),
  SupportedLanguage('it', 'Italiano', 'Italian'),
  SupportedLanguage('pt', 'Português', 'Portuguese'),
  SupportedLanguage('tr', 'Türkçe', 'Turkish'),
  SupportedLanguage('ko', '한국어', 'Korean'),
  SupportedLanguage('ar', 'العربية', 'Arabic'),
  SupportedLanguage('hi', 'हिन्दी', 'Hindi'),
];

final supportedLocales = supportedLanguages
    .map((item) => Locale(item.code))
    .toList();

class AppText {
  static final _cyrillic = RegExp(r'[\u0400-\u04ff]');
  static final Map<String, List<MapEntry<String, String>>> _fragmentCache = {};

  static String get(String code, String key) {
    if (code == 'ru') return _ru[key] ?? key;
    if (code == 'en') return _en[key] ?? _ru[key] ?? key;
    final localized = _localized[code]?[key];
    final isCurated =
        localized != null && localized != _en[key] && localized != _ru[key];
    if (isCurated) return localized;
    final source = _ru[key];
    final generated = source == null
        ? null
        : generatedUiTranslations[code]?[source];
    return generated ?? localized ?? _en[key] ?? source ?? key;
  }

  static SupportedLanguage language(String code) {
    return supportedLanguages.firstWhere(
      (item) => item.code == code,
      orElse: () => supportedLanguages.first,
    );
  }

  static String of(BuildContext context, String key) =>
      get(Localizations.localeOf(context).languageCode, key);

  static String phrase(BuildContext context, String source) =>
      phraseFor(Localizations.localeOf(context).languageCode, source);

  static String phraseFor(String code, String source) {
    if (code == 'ru' || source.trim().isEmpty) return source;
    final semanticKey = _ru.entries
        .where((entry) => entry.value == source)
        .map((entry) => entry.key)
        .firstOrNull;
    if (semanticKey != null) return get(code, semanticKey);
    final generated = generatedUiTranslations[code]?[source];
    if (generated != null && generated.trim().isNotEmpty) return generated;
    final curated = _uiPhrasesEn[source];
    if (curated != null) return curated;
    if (!_cyrillic.hasMatch(source)) return source;
    final fragments = _fragmentCache.putIfAbsent(code, () {
      final entries = generatedUiTranslations[code]?.entries.toList() ?? [];
      entries.sort(
        (left, right) => right.key.length.compareTo(left.key.length),
      );
      return entries;
    });
    var result = source;
    for (final entry in fragments) {
      if (entry.key == source || !result.contains(entry.key)) continue;
      final pattern = RegExp(
        '(?<![\\u0400-\\u04ff])${RegExp.escape(entry.key)}(?![\\u0400-\\u04ff])',
      );
      result = result.replaceAll(pattern, entry.value);
    }
    return result;
  }
}

const medicalDisclaimer =
    'Это справочная информация, не диагноз и не назначение лечения. Для точной интерпретации обратитесь к врачу.';

const _ru = <String, String>{
  'appName': 'Моё здоровье',
  'loading': 'Загружаем локальный сейф здоровья',
  'today': 'Сегодня',
  'health': 'Здоровье',
  'profile': 'Профиль',
  'medicalCard': 'Медкарта',
  'labs': 'Анализы',
  'medicines': 'Лекарства',
  'symptoms': 'Симптомы',
  'knowledge': 'Справочник',
  'workouts': 'Тренировки',
  'exercises': 'База упражнений',
  'nutrition': 'Питание',
  'recipes': 'Рецепты',
  'foodPhoto': 'Фото еды',
  'sleep': 'Сон и будильники',
  'calendar': 'Календарь',
  'vacation': 'Отпуск',
  'trips': 'Командировки',
  'climate': 'Климат',
  'analytics': 'Аналитика',
  'assistant': 'Ассистент',
  'devices': 'Устройства',
  'documents': 'Документы',
  'settings': 'Настройки',
  'more': 'Ещё',
  'quickAdd': 'Быстрый ввод',
  'search': 'Поиск',
  'exportPdf': 'PDF врачу',
  'save': 'Сохранить',
  'cancel': 'Отмена',
  'next': 'Далее',
  'back': 'Назад',
  'finish': 'Готово',
  'skipOptional': 'Пропустить',
  'onboardingTitle': 'Первичная настройка',
  'onboardingSubtitle':
      'Заполните самое важное сейчас, остальное можно добавить позже.',
  'readiness': 'Готовность',
  'energy': 'Энергия',
  'water': 'Вода',
  'steps': 'Шаги',
  'sleepHours': 'Сон',
  'weight': 'Вес',
  'calories': 'Ккал',
  'workoutMinutes': 'Тренировка',
  'mood': 'Самочувствие',
  'stress': 'Стресс',
  'aiSummary': 'ИИ-анализ дня',
  'confirmations': 'Нужно подтвердить',
  'reminders': 'Напоминания',
  'privacy': 'Приватность',
  'theme': 'Тема',
  'howToDo': 'Как выполнять',
  'warning': 'Предупреждение',
  'ingredients': 'Ингредиенты',
  'cooking': 'Приготовление',
  'close': 'Закрыть',
  'minShort': 'мин',
  'kcalShort': 'ккал',
  'protein': 'белок',
  'gramShort': 'г',
  'noWorkoutExercises': 'В тренировке пока нет упражнений из каталога.',
  'exerciseCatalogSubtitle': 'упражнений с техникой и предупреждениями',
  'recipeCatalogSubtitle': 'рабочих рецептов для дома, дороги и восстановления',
  'medicalDisclaimer': medicalDisclaimer,
  'activeCalories': 'Активный расход',
  'basalBurn': 'Базовый расход',
  'bodyFat': 'Жир',
  'weatherClimate': 'Погода и климат',
  'quickActions': 'Быстрые действия',
  'medicalData': 'Медицинские данные',
  'goals': 'Цели',
  'equipment': 'Инвентарь',
  'add': 'Добавить',
  'delete': 'Удалить',
  'edit': 'Редактировать',
  'confirm': 'Подтвердить',
  'open': 'Открыть',
  'restore': 'Восстановить',
};

const _en = <String, String>{
  'appName': 'My Health',
  'loading': 'Loading local health vault',
  'today': 'Today',
  'health': 'Health',
  'profile': 'Profile',
  'medicalCard': 'Medical card',
  'labs': 'Labs',
  'medicines': 'Medicines',
  'symptoms': 'Symptoms',
  'knowledge': 'Health guide',
  'workouts': 'Workouts',
  'exercises': 'Exercise base',
  'nutrition': 'Nutrition',
  'recipes': 'Recipes',
  'foodPhoto': 'Food photo',
  'sleep': 'Sleep and alarms',
  'calendar': 'Calendar',
  'vacation': 'Vacation',
  'trips': 'Business trips',
  'climate': 'Climate',
  'analytics': 'Analytics',
  'assistant': 'Assistant',
  'devices': 'Devices',
  'documents': 'Documents',
  'settings': 'Settings',
  'more': 'More',
  'quickAdd': 'Quick add',
  'search': 'Search',
  'exportPdf': 'Doctor PDF',
  'save': 'Save',
  'cancel': 'Cancel',
  'next': 'Next',
  'back': 'Back',
  'finish': 'Finish',
  'skipOptional': 'Skip',
  'onboardingTitle': 'First setup',
  'onboardingSubtitle': 'Add the essentials now; everything else can wait.',
  'readiness': 'Readiness',
  'energy': 'Energy',
  'water': 'Water',
  'steps': 'Steps',
  'sleepHours': 'Sleep',
  'weight': 'Weight',
  'calories': 'Calories',
  'workoutMinutes': 'Workout',
  'mood': 'Wellbeing',
  'stress': 'Stress',
  'aiSummary': 'AI day summary',
  'confirmations': 'Needs confirmation',
  'reminders': 'Reminders',
  'privacy': 'Privacy',
  'theme': 'Theme',
  'howToDo': 'How to do it',
  'warning': 'Warning',
  'ingredients': 'Ingredients',
  'cooking': 'Cooking',
  'close': 'Close',
  'minShort': 'min',
  'kcalShort': 'kcal',
  'protein': 'protein',
  'gramShort': 'g',
  'noWorkoutExercises': 'This workout has no catalog exercises yet.',
  'exerciseCatalogSubtitle': 'exercises with technique and warnings',
  'recipeCatalogSubtitle': 'practical recipes for home, travel, and recovery',
  'medicalDisclaimer':
      'This information is for reference only. It is not a diagnosis or treatment prescription. Consult a doctor for accurate interpretation.',
  'activeCalories': 'Active calories',
  'basalBurn': 'Basal burn',
  'bodyFat': 'Body fat',
  'weatherClimate': 'Weather and climate',
  'quickActions': 'Quick actions',
  'medicalData': 'Medical data',
  'goals': 'Goals',
  'equipment': 'Equipment',
  'add': 'Add',
  'delete': 'Delete',
  'edit': 'Edit',
  'confirm': 'Confirm',
  'open': 'Open',
  'restore': 'Restore',
};

const _uiPhrasesEn = <String, String>{
  'Параметры питания': 'Nutrition preferences',
  'Подбор на сегодня': 'Today’s suggestions',
  'Приёмы пищи': 'Meals',
  'Планы тренировок': 'Workout plans',
  'Работа и отдых': 'Work and rest',
  'Напоминания активности': 'Activity reminders',
  'Резервные копии и перенос данных': 'Backups and data transfer',
  'Системное хранилище здоровья': 'System health store',
  'Динамика': 'Trends',
  'Динамика анализов': 'Lab trends',
  'Интерпретация': 'Interpretation',
  'Сегодня': 'Today',
  'Вес': 'Weight',
  'Сон': 'Sleep',
  'Шаги': 'Steps',
  'Вода': 'Water',
  'Калории': 'Calories',
  'Клетчатка': 'Fiber',
  'Белок': 'Protein',
  'Лекарства': 'Medicines',
  'Симптомы': 'Symptoms',
  'Документы': 'Documents',
  'Медкарта': 'Medical card',
  'Готовность': 'Readiness',
  'Энергия': 'Energy',
};

final _localized = <String, Map<String, String>>{
  'ru': _ru,
  'en': _en,
  'zh': {
    ..._en,
    'appName': '我的健康',
    'medicalDisclaimer': '此信息仅供参考，不构成诊断或治疗建议。请咨询医生以获得准确解读。',
    'today': '今天',
    'health': '健康',
    'profile': '档案',
    'workouts': '训练',
    'nutrition': '营养',
    'calendar': '日历',
    'more': '更多',
    'assistant': '助手',
    'knowledge': '健康知识库',
    'settings': '设置',
  },
  'ja': {
    ..._en,
    'appName': '私の健康',
    'medicalDisclaimer': 'これは参考情報であり、診断や治療の指示ではありません。正確な解釈については医師にご相談ください。',
    'today': '今日',
    'health': '健康',
    'profile': 'プロフィール',
    'workouts': 'トレーニング',
    'nutrition': '栄養',
    'calendar': 'カレンダー',
    'more': 'その他',
    'assistant': 'アシスタント',
    'knowledge': '健康ガイド',
    'settings': '設定',
  },
  'be': {
    ..._ru,
    'appName': 'Маё здароўе',
    'medicalDisclaimer':
        'Гэта даведачная інфармацыя, а не дыягназ і не прызначэнне лячэння. Для дакладнага тлумачэння звярніцеся да ўрача.',
    'today': 'Сёння',
    'health': 'Здароўе',
    'profile': 'Профіль',
    'workouts': 'Трэніроўкі',
    'nutrition': 'Харчаванне',
    'calendar': 'Каляндар',
    'more': 'Яшчэ',
    'assistant': 'Асістэнт',
    'knowledge': 'Даведнік',
    'settings': 'Налады',
  },
  'kk': {
    ..._ru,
    'appName': 'Менің денсаулығым',
    'medicalDisclaimer':
        'Бұл анықтамалық ақпарат, диагноз немесе ем тағайындау емес. Дәл түсіндіру үшін дәрігерге жүгініңіз.',
    'today': 'Бүгін',
    'health': 'Денсаулық',
    'profile': 'Профиль',
    'workouts': 'Жаттығулар',
    'nutrition': 'Тамақтану',
    'calendar': 'Күнтізбе',
    'more': 'Тағы',
    'assistant': 'Ассистент',
    'knowledge': 'Анықтамалық',
    'settings': 'Баптаулар',
  },
  'de': {
    ..._en,
    'appName': 'Meine Gesundheit',
    'medicalDisclaimer':
        'Diese Informationen dienen nur zur Orientierung und sind weder Diagnose noch Behandlungsempfehlung. Wenden Sie sich für eine genaue Beurteilung an einen Arzt.',
    'today': 'Heute',
    'health': 'Gesundheit',
    'profile': 'Profil',
    'workouts': 'Training',
    'nutrition': 'Ernährung',
    'calendar': 'Kalender',
    'more': 'Mehr',
    'assistant': 'Assistent',
    'knowledge': 'Gesundheitswissen',
    'settings': 'Einstellungen',
  },
  'fr': {
    ..._en,
    'appName': 'Ma santé',
    'medicalDisclaimer':
        'Ces informations sont fournies à titre indicatif et ne constituent ni un diagnostic ni une prescription. Consultez un médecin pour une interprétation précise.',
    'today': 'Aujourd’hui',
    'health': 'Santé',
    'profile': 'Profil',
    'workouts': 'Entraînements',
    'nutrition': 'Nutrition',
    'calendar': 'Calendrier',
    'more': 'Plus',
    'assistant': 'Assistant',
    'knowledge': 'Guide santé',
    'settings': 'Réglages',
  },
  'es': {
    ..._en,
    'appName': 'Mi salud',
    'medicalDisclaimer':
        'Esta información es solo orientativa; no es un diagnóstico ni una prescripción de tratamiento. Consulte a un médico para una interpretación precisa.',
    'today': 'Hoy',
    'health': 'Salud',
    'profile': 'Perfil',
    'workouts': 'Entrenos',
    'nutrition': 'Nutrición',
    'calendar': 'Calendario',
    'more': 'Más',
    'assistant': 'Asistente',
    'knowledge': 'Guía de salud',
    'settings': 'Ajustes',
  },
  'it': {
    ..._en,
    'appName': 'La mia salute',
    'medicalDisclaimer':
        'Queste informazioni sono solo indicative e non costituiscono una diagnosi né una prescrizione. Consulta un medico per un’interpretazione accurata.',
    'today': 'Oggi',
    'health': 'Salute',
    'workouts': 'Allenamenti',
    'nutrition': 'Nutrizione',
    'calendar': 'Calendario',
    'more': 'Altro',
    'assistant': 'Assistente',
    'knowledge': 'Guida alla salute',
    'settings': 'Impostazioni',
  },
  'pt': {
    ..._en,
    'appName': 'Minha saúde',
    'medicalDisclaimer':
        'Estas informações são apenas de referência e não constituem diagnóstico nem prescrição de tratamento. Consulte um médico para uma interpretação precisa.',
    'today': 'Hoje',
    'health': 'Saúde',
    'workouts': 'Treinos',
    'nutrition': 'Nutrição',
    'calendar': 'Calendário',
    'more': 'Mais',
    'assistant': 'Assistente',
    'knowledge': 'Guia de saúde',
    'settings': 'Definições',
  },
  'tr': {
    ..._en,
    'appName': 'Sağlığım',
    'medicalDisclaimer':
        'Bu bilgiler yalnızca referans amaçlıdır; tanı veya tedavi önerisi değildir. Doğru yorum için bir doktora danışın.',
    'today': 'Bugün',
    'health': 'Sağlık',
    'workouts': 'Antrenmanlar',
    'nutrition': 'Beslenme',
    'calendar': 'Takvim',
    'more': 'Daha fazla',
    'assistant': 'Asistan',
    'knowledge': 'Sağlık rehberi',
    'settings': 'Ayarlar',
  },
  'ko': {
    ..._en,
    'appName': '나의 건강',
    'medicalDisclaimer': '이 정보는 참고용이며 진단이나 치료 처방이 아닙니다. 정확한 해석은 의사와 상담하세요.',
    'today': '오늘',
    'health': '건강',
    'workouts': '운동',
    'nutrition': '영양',
    'calendar': '달력',
    'more': '더보기',
    'assistant': '도우미',
    'knowledge': '건강 정보',
    'settings': '설정',
  },
  'ar': {
    ..._en,
    'appName': 'صحتي',
    'medicalDisclaimer':
        'هذه معلومات مرجعية وليست تشخيصًا أو وصفًا للعلاج. استشر طبيبًا للحصول على تفسير دقيق.',
    'today': 'اليوم',
    'health': 'الصحة',
    'workouts': 'التمارين',
    'nutrition': 'التغذية',
    'calendar': 'التقويم',
    'more': 'المزيد',
    'assistant': 'المساعد',
    'knowledge': 'الدليل الصحي',
    'settings': 'الإعدادات',
  },
  'hi': {
    ..._en,
    'appName': 'मेरा स्वास्थ्य',
    'medicalDisclaimer':
        'यह जानकारी केवल संदर्भ के लिए है; यह निदान या उपचार का नुस्खा नहीं है। सटीक व्याख्या के लिए डॉक्टर से परामर्श करें।',
    'today': 'आज',
    'health': 'स्वास्थ्य',
    'workouts': 'वर्कआउट',
    'nutrition': 'पोषण',
    'calendar': 'कैलेंडर',
    'more': 'अधिक',
    'assistant': 'सहायक',
    'knowledge': 'स्वास्थ्य मार्गदर्शिका',
    'settings': 'सेटिंग्स',
  },
};
