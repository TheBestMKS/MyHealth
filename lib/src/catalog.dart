class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.focus,
    required this.equipment,
    required this.level,
    required this.minutes,
    required this.instructions,
    required this.warning,
  });

  final String id;
  final String title;
  final String focus;
  final String equipment;
  final String level;
  final int minutes;
  final String instructions;
  final String warning;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.kind,
    required this.minutes,
    required this.calories,
    required this.protein,
    required this.tags,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String title;
  final String kind;
  final int minutes;
  final int calories;
  final int protein;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> steps;
}

extension ExerciseCatalogText on Exercise {
  String titleFor(String localeCode) =>
      _catalogText(_exerciseTranslations, localeCode, id, 'title', title);

  String focusFor(String localeCode) =>
      _catalogText(_exerciseTranslations, localeCode, id, 'focus', focus);

  String equipmentFor(String localeCode) => _catalogText(
    _exerciseTranslations,
    localeCode,
    id,
    'equipment',
    equipment,
  );

  String levelFor(String localeCode) =>
      _catalogText(_exerciseTranslations, localeCode, id, 'level', level);

  String instructionsFor(String localeCode) => _catalogText(
    _exerciseTranslations,
    localeCode,
    id,
    'instructions',
    instructions,
  );

  String warningFor(String localeCode) =>
      _catalogText(_exerciseTranslations, localeCode, id, 'warning', warning);
}

extension RecipeCatalogText on Recipe {
  String titleFor(String localeCode) =>
      _catalogText(_recipeTranslations, localeCode, id, 'title', title);

  String kindFor(String localeCode) =>
      _catalogText(_recipeTranslations, localeCode, id, 'kind', kind);

  List<String> tagsFor(String localeCode) =>
      _catalogList(_recipeTranslations, localeCode, id, 'tags', tags);

  List<String> ingredientsFor(String localeCode) => _catalogList(
    _recipeTranslations,
    localeCode,
    id,
    'ingredients',
    ingredients,
  );

  List<String> stepsFor(String localeCode) =>
      _catalogList(_recipeTranslations, localeCode, id, 'steps', steps);
}

String _catalogText(
  Map<String, Map<String, Map<String, Object>>> translations,
  String localeCode,
  String id,
  String field,
  String fallback,
) {
  final locale = _catalogLocale(localeCode);
  final translated = translations[locale]?[id]?[field];
  if (translated is String && translated.isNotEmpty) {
    return translated;
  }
  final english = translations['en']?[id]?[field];
  if (locale != 'ru' && english is String && english.isNotEmpty) {
    return english;
  }
  return fallback;
}

List<String> _catalogList(
  Map<String, Map<String, Map<String, Object>>> translations,
  String localeCode,
  String id,
  String field,
  List<String> fallback,
) {
  final locale = _catalogLocale(localeCode);
  final translated = translations[locale]?[id]?[field];
  if (translated is List<String> && translated.isNotEmpty) {
    return translated;
  }
  final english = translations['en']?[id]?[field];
  if (locale != 'ru' && english is List<String> && english.isNotEmpty) {
    return english;
  }
  return fallback;
}

String _catalogLocale(String localeCode) {
  final normalized = localeCode.toLowerCase().replaceAll('_', '-');
  return normalized.split('-').first;
}

const _exerciseTranslations = <String, Map<String, Map<String, Object>>>{
  'en': {
    'goblet-squat': {
      'title': 'Goblet squat',
      'focus': 'legs, core',
      'equipment': 'dumbbell',
      'level': 'beginner',
      'instructions':
          'Stand with feet hip-width apart, hold the dumbbell at your chest, let knees track over toes, and keep a neutral spine.',
      'warning': 'Stop if you feel sharp pain in the knee or lower back.',
    },
    'romanian-deadlift': {
      'title': 'Dumbbell Romanian deadlift',
      'focus': 'hamstrings, back',
      'equipment': 'dumbbells',
      'level': 'intermediate',
      'instructions':
          'Hinge hips back, keep dumbbells close to your legs, and stand up by driving through the glutes.',
      'warning':
          'Do not round the lower back; reduce weight if your technique slips.',
    },
    'dead-bug': {
      'title': 'Dead bug',
      'focus': 'core',
      'equipment': 'mat',
      'level': 'beginner',
      'instructions':
          'Keep the lower back gently pressed to the floor and alternate extending the opposite arm and leg.',
      'warning': 'Breathe steadily and avoid any lower-back pain.',
    },
    'push-up': {
      'title': 'Floor or elevated push-up',
      'focus': 'chest, shoulders, triceps',
      'equipment': 'bodyweight',
      'level': 'beginner',
      'instructions':
          'Keep the body in one line, hands under shoulders, and lower under control.',
      'warning': 'If wrists hurt, move to a higher support.',
    },
    'band-row': {
      'title': 'Resistance band row',
      'focus': 'back',
      'equipment': 'resistance band',
      'level': 'beginner',
      'instructions':
          'Set the shoulder blades, pull elbows back, and keep shoulders away from the ears.',
      'warning': 'Check the band anchor before each set.',
    },
    'plank': {
      'title': 'Forearm plank',
      'focus': 'core',
      'equipment': 'mat',
      'level': 'beginner',
      'instructions':
          'Place elbows under shoulders, keep hips from sagging, and breathe in short steady cycles.',
      'warning': 'Finish the set if your lower back starts hurting.',
    },
    'split-squat': {
      'title': 'Bulgarian split squat',
      'focus': 'legs, balance',
      'equipment': 'support',
      'level': 'intermediate',
      'instructions':
          'Put the rear foot on a support, lean slightly forward, and move slowly with control.',
      'warning': 'Reduce depth if the knee feels uncomfortable.',
    },
    'farmer-walk': {
      'title': "Farmer's carry",
      'focus': 'grip, core, posture',
      'equipment': 'dumbbells',
      'level': 'intermediate',
      'instructions':
          'Walk tall with shoulders down, core braced, and short stable steps.',
      'warning': 'Do not hold your breath for long carries.',
    },
    'cat-cow': {
      'title': 'Cat-cow',
      'focus': 'spine mobility',
      'equipment': 'mat',
      'level': 'beginner',
      'instructions':
          'Gently arch on inhale and round on exhale, moving without jerks.',
      'warning': 'Keep the range of motion comfortable.',
    },
    'hip-flexor-stretch': {
      'title': 'Hip flexor stretch',
      'focus': 'hips, thigh',
      'equipment': 'mat',
      'level': 'beginner',
      'instructions':
          'Place one knee on the mat, tuck the pelvis, and glide forward until you feel mild tension.',
      'warning': 'Do not overarch the lower back to chase more range.',
    },
    'box-breathing': {
      'title': 'Box breathing',
      'focus': 'stress, recovery',
      'equipment': 'bodyweight',
      'level': 'beginner',
      'instructions':
          'Inhale for 4 counts, hold for 4, exhale for 4, hold for 4. Repeat 4-6 cycles.',
      'warning': 'Stop if you feel dizzy.',
    },
    'step-up': {
      'title': 'Step-up onto stable support',
      'focus': 'legs, cardio',
      'equipment': 'support',
      'level': 'beginner',
      'instructions':
          'Place the full foot on the support, step up without pushing hard from the rear leg, and alternate sides.',
      'warning': 'The support must be stable and non-slip.',
    },
    'shoulder-press': {
      'title': 'Standing dumbbell press',
      'focus': 'shoulders, core',
      'equipment': 'dumbbells',
      'level': 'intermediate',
      'instructions':
          'Keep ribs down, lightly tense the glutes, and press dumbbells overhead in a smooth arc.',
      'warning': 'Do not train through shoulder pain.',
    },
    'glute-bridge': {
      'title': 'Glute bridge',
      'focus': 'glutes, hamstrings',
      'equipment': 'mat',
      'level': 'beginner',
      'instructions':
          'Place feet close to the hips, lift through the glutes, and avoid overextending at the top.',
      'warning': 'If hamstrings cramp, move the feet closer to the body.',
    },
    'bird-dog': {
      'title': 'Bird dog',
      'focus': 'core, stability',
      'equipment': 'mat',
      'level': 'beginner',
      'instructions':
          'From all fours, extend the opposite arm and leg while keeping the pelvis level.',
      'warning': 'Reduce range if you lose balance.',
    },
    'low-impact-interval': {
      'title': 'Low-impact intervals',
      'focus': 'cardio',
      'equipment': 'bodyweight',
      'level': 'intermediate',
      'instructions':
          'Alternate 40 seconds of marching, step-touch, and knee lifts with 20 seconds of rest.',
      'warning': 'Keep intensity conversational when sleep has been poor.',
    },
  },
};

const _recipeTranslations = <String, Map<String, Map<String, Object>>>{
  'en': {
    'oat-berry-yogurt': {
      'title': 'Oats with berries and Greek yogurt',
      'kind': 'breakfast',
      'tags': ['quick', 'protein', 'no frying'],
      'ingredients': ['oats', 'Greek yogurt', 'berries', 'nuts'],
      'steps': [
        'Cook the oats in water or milk.',
        'Add yogurt, berries, and a small amount of nuts.',
        'Check the portion against your calorie goal.',
      ],
    },
    'buckwheat-chicken-bowl': {
      'title': 'Buckwheat bowl with chicken and vegetables',
      'kind': 'lunch',
      'tags': ['filling', 'training day', 'meal prep'],
      'ingredients': [
        'buckwheat',
        'chicken breast',
        'cucumber',
        'tomatoes',
        'greens',
      ],
      'steps': [
        'Cook the buckwheat and slice the vegetables.',
        'Pan-cook or bake the chicken until done.',
        'Assemble the bowl and add greens with a yogurt sauce.',
      ],
    },
    'tuna-salad': {
      'title': 'Tuna, bean, and egg salad',
      'kind': 'dinner',
      'tags': ['quick', 'omega-3', 'business trip'],
      'ingredients': ['tuna', 'egg', 'beans', 'salad greens', 'olive oil'],
      'steps': [
        'Combine salad greens, beans, and tuna.',
        'Add the egg and a spoon of olive oil.',
        'Salt moderately, considering fluid retention after travel.',
      ],
    },
    'lentil-soup': {
      'title': 'Lentil soup with vegetables',
      'kind': 'lunch',
      'tags': ['fiber', '2-day cooking', 'plant protein'],
      'ingredients': ['lentils', 'carrot', 'onion', 'tomatoes', 'paprika'],
      'steps': [
        'Saute the onion and carrot.',
        'Add lentils, tomatoes, and water.',
        'Cook until tender, then adjust salt.',
      ],
    },
    'salmon-potato': {
      'title': 'Salmon with potatoes and broccoli',
      'kind': 'dinner',
      'tags': ['recovery', 'omega-3', 'post-workout'],
      'ingredients': ['salmon', 'potatoes', 'broccoli', 'lemon', 'dill'],
      'steps': [
        'Bake potatoes and salmon on one tray.',
        'Steam the broccoli.',
        'Add lemon and dill before serving.',
      ],
    },
    'cottage-cheese-bowl': {
      'title': 'Cottage cheese bowl with fruit',
      'kind': 'snack',
      'tags': ['protein', 'no stove', 'post-workout'],
      'ingredients': ['cottage cheese', 'banana', 'berries', 'chia seeds'],
      'steps': [
        'Mix cottage cheese with berries.',
        'Add half a banana and seeds.',
        'If lactose intolerant, use a lactose-free option.',
      ],
    },
    'turkey-wrap': {
      'title': 'Turkey and hummus wrap',
      'kind': 'lunch',
      'tags': ['travel', 'no reheating', 'balanced'],
      'ingredients': ['tortilla', 'turkey', 'hummus', 'lettuce', 'cucumber'],
      'steps': [
        'Spread hummus over the tortilla.',
        'Add turkey and vegetables.',
        'Roll tightly and cut in half.',
      ],
    },
    'tofu-rice': {
      'title': 'Tofu with rice and vegetables',
      'kind': 'dinner',
      'tags': ['plant protein', 'Asian style', 'filling'],
      'ingredients': ['tofu', 'rice', 'carrot', 'pepper', 'soy sauce'],
      'steps': [
        'Pat tofu dry and pan-fry cubes.',
        'Add vegetables and a little sauce.',
        'Serve with rice and green onion.',
      ],
    },
    'egg-vegetable-omelet': {
      'title': 'Omelet with vegetables and cheese',
      'kind': 'breakfast',
      'tags': ['low carb', 'quick', 'satiety'],
      'ingredients': ['eggs', 'pepper', 'spinach', 'cheese', 'tomatoes'],
      'steps': [
        'Lightly soften the vegetables.',
        'Pour in the eggs and cook covered.',
        'Add cheese at the end.',
      ],
    },
    'recovery-smoothie': {
      'title': 'Recovery smoothie',
      'kind': 'snack',
      'tags': ['post-workout', 'quick', 'soft food'],
      'ingredients': ['kefir', 'banana', 'protein powder', 'berries', 'oats'],
      'steps': [
        'Place ingredients into a blender.',
        'Blend until smooth.',
        'Use a plant drink if sensitive to dairy.',
      ],
    },
    'hotel-breakfast-plate': {
      'title': 'Hotel breakfast plate',
      'kind': 'breakfast',
      'tags': ['business trip', 'no kitchen', 'choice control'],
      'ingredients': [
        'eggs',
        'yogurt',
        'fruit',
        'whole-grain bread',
        'vegetables',
      ],
      'steps': [
        'Start with protein: eggs or yogurt.',
        'Add vegetables and one fruit.',
        'Keep sweet pastry as a small extra, not the base.',
      ],
    },
    'sick-day-broth': {
      'title': 'Light broth with rice',
      'kind': 'recovery',
      'tags': ['sick day', 'gentle', 'hydration'],
      'ingredients': ['chicken broth', 'rice', 'carrot', 'greens'],
      'steps': [
        'Cook rice in broth until soft.',
        'Add carrot and greens.',
        'Eat small portions and monitor how you feel.',
      ],
    },
  },
};

const exerciseCatalog = <Exercise>[
  Exercise(
    id: 'goblet-squat',
    title: 'Присед с гантелью у груди',
    focus: 'ноги, корпус',
    equipment: 'гантель',
    level: 'начальный',
    minutes: 8,
    instructions:
        'Стопы на ширине таза, гантель у груди, колени движутся по линии носков, спина нейтральна.',
    warning: 'Остановитесь при резкой боли в колене или пояснице.',
  ),
  Exercise(
    id: 'romanian-deadlift',
    title: 'Румынская тяга с гантелями',
    focus: 'задняя поверхность бедра, спина',
    equipment: 'гантели',
    level: 'средний',
    minutes: 8,
    instructions:
        'Уведите таз назад, держите гантели близко к ногам, поднимайтесь за счёт ягодиц.',
    warning: 'Не округляйте поясницу, снижайте вес при потере техники.',
  ),
  Exercise(
    id: 'dead-bug',
    title: 'Dead bug',
    focus: 'корпус',
    equipment: 'коврик',
    level: 'начальный',
    minutes: 5,
    instructions:
        'Поясница мягко прижата к полу, поочерёдно вытягивайте противоположные руку и ногу.',
    warning: 'Держите дыхание ровным, не допускайте боли в пояснице.',
  ),
  Exercise(
    id: 'push-up',
    title: 'Отжимания от пола или опоры',
    focus: 'грудь, плечи, трицепс',
    equipment: 'без оборудования',
    level: 'начальный',
    minutes: 7,
    instructions:
        'Корпус одной линией, ладони под плечами, опускайтесь контролируемо.',
    warning: 'При боли в запястье перейдите на опору выше.',
  ),
  Exercise(
    id: 'band-row',
    title: 'Тяга эспандера к поясу',
    focus: 'спина',
    equipment: 'эспандер',
    level: 'начальный',
    minutes: 6,
    instructions:
        'Зафиксируйте лопатки, тяните локти назад, не поднимайте плечи к ушам.',
    warning: 'Проверьте крепление эспандера перед подходом.',
  ),
  Exercise(
    id: 'plank',
    title: 'Планка на предплечьях',
    focus: 'корпус',
    equipment: 'коврик',
    level: 'начальный',
    minutes: 4,
    instructions:
        'Локти под плечами, таз не провисает, дыхание ровное короткими циклами.',
    warning: 'Завершите подход, если начинает болеть поясница.',
  ),
  Exercise(
    id: 'split-squat',
    title: 'Болгарский сплит-присед',
    focus: 'ноги, баланс',
    equipment: 'опора',
    level: 'средний',
    minutes: 9,
    instructions:
        'Задняя нога на опоре, корпус слегка наклонён, движение медленное и устойчивое.',
    warning: 'При дискомфорте в колене уменьшите глубину.',
  ),
  Exercise(
    id: 'farmer-walk',
    title: 'Прогулка фермера',
    focus: 'хват, корпус, осанка',
    equipment: 'гантели',
    level: 'средний',
    minutes: 6,
    instructions:
        'Идите ровно, плечи опущены, корпус собран, шаги короткие и стабильные.',
    warning: 'Не задерживайте дыхание на длинных отрезках.',
  ),
  Exercise(
    id: 'cat-cow',
    title: 'Кошка-корова',
    focus: 'мобильность позвоночника',
    equipment: 'коврик',
    level: 'начальный',
    minutes: 4,
    instructions:
        'На вдохе мягко прогнитесь, на выдохе округлите спину, двигайтесь без рывков.',
    warning: 'Диапазон движения должен оставаться комфортным.',
  ),
  Exercise(
    id: 'hip-flexor-stretch',
    title: 'Растяжка сгибателей бедра',
    focus: 'таз, бедро',
    equipment: 'коврик',
    level: 'начальный',
    minutes: 5,
    instructions:
        'Колено на коврике, таз подкручен, мягко смещайтесь вперёд до умеренного натяжения.',
    warning: 'Не прогибайтесь в пояснице ради большей амплитуды.',
  ),
  Exercise(
    id: 'box-breathing',
    title: 'Квадратное дыхание',
    focus: 'стресс, восстановление',
    equipment: 'без оборудования',
    level: 'начальный',
    minutes: 4,
    instructions:
        'Вдох 4 счёта, пауза 4, выдох 4, пауза 4. Повторите 4-6 циклов.',
    warning: 'Прекратите при головокружении.',
  ),
  Exercise(
    id: 'step-up',
    title: 'Шаги на устойчивую опору',
    focus: 'ноги, кардио',
    equipment: 'опора',
    level: 'начальный',
    minutes: 8,
    instructions:
        'Ставьте стопу полностью, поднимайтесь без толчка задней ногой, чередуйте стороны.',
    warning: 'Опора должна быть устойчивой и нескользкой.',
  ),
  Exercise(
    id: 'shoulder-press',
    title: 'Жим гантелей стоя',
    focus: 'плечи, корпус',
    equipment: 'гантели',
    level: 'средний',
    minutes: 7,
    instructions:
        'Рёбра опущены, ягодицы слегка напряжены, жмите гантели по дуге над головой.',
    warning: 'Не выполняйте через боль в плече.',
  ),
  Exercise(
    id: 'glute-bridge',
    title: 'Ягодичный мост',
    focus: 'ягодицы, задняя поверхность бедра',
    equipment: 'коврик',
    level: 'начальный',
    minutes: 6,
    instructions:
        'Стопы близко к тазу, поднимайтесь за счёт ягодиц, верхняя точка без переразгибания.',
    warning: 'Если сводит заднюю поверхность бедра, поставьте стопы ближе.',
  ),
  Exercise(
    id: 'bird-dog',
    title: 'Bird dog',
    focus: 'корпус, стабилизация',
    equipment: 'коврик',
    level: 'начальный',
    minutes: 5,
    instructions:
        'Из положения на четвереньках вытягивайте противоположные руку и ногу, таз ровный.',
    warning: 'Снижайте амплитуду, если теряется баланс.',
  ),
  Exercise(
    id: 'low-impact-interval',
    title: 'Низкоударные интервалы',
    focus: 'кардио',
    equipment: 'без оборудования',
    level: 'средний',
    minutes: 12,
    instructions:
        'Чередуйте 40 секунд марш на месте, степ-тач, подъём колена и 20 секунд отдыха.',
    warning: 'Держите интенсивность разговорной при недосыпе.',
  ),
];

const recipeCatalog = <Recipe>[
  Recipe(
    id: 'oat-berry-yogurt',
    title: 'Овсянка с ягодами и греческим йогуртом',
    kind: 'завтрак',
    minutes: 12,
    calories: 420,
    protein: 24,
    tags: ['быстро', 'белок', 'без жарки'],
    ingredients: ['овсяные хлопья', 'греческий йогурт', 'ягоды', 'орехи'],
    steps: [
      'Сварите хлопья на воде или молоке.',
      'Добавьте йогурт, ягоды и немного орехов.',
      'Проверьте порцию по цели калорийности.',
    ],
  ),
  Recipe(
    id: 'buckwheat-chicken-bowl',
    title: 'Гречневая тарелка с курицей и овощами',
    kind: 'обед',
    minutes: 28,
    calories: 610,
    protein: 42,
    tags: ['сытно', 'для тренировки', 'контейнер'],
    ingredients: ['гречка', 'куриная грудка', 'огурец', 'томаты', 'зелень'],
    steps: [
      'Отварите гречку и нарежьте овощи.',
      'Обжарьте или запеките курицу до готовности.',
      'Соберите тарелку, добавьте зелень и йогуртовый соус.',
    ],
  ),
  Recipe(
    id: 'tuna-salad',
    title: 'Салат с тунцом, фасолью и яйцом',
    kind: 'ужин',
    minutes: 15,
    calories: 390,
    protein: 33,
    tags: ['быстро', 'омега-3', 'командировка'],
    ingredients: [
      'тунец',
      'яйцо',
      'фасоль',
      'листья салата',
      'оливковое масло',
    ],
    steps: [
      'Смешайте салатные листья, фасоль и тунец.',
      'Добавьте яйцо и ложку оливкового масла.',
      'Посолите умеренно, учитывая задержку воды после дороги.',
    ],
  ),
  Recipe(
    id: 'lentil-soup',
    title: 'Чечевичный суп с овощами',
    kind: 'обед',
    minutes: 35,
    calories: 460,
    protein: 25,
    tags: ['клетчатка', 'готовка на 2 дня', 'растительный белок'],
    ingredients: ['чечевица', 'морковь', 'лук', 'томаты', 'паприка'],
    steps: [
      'Пассеруйте лук и морковь.',
      'Добавьте чечевицу, томаты и воду.',
      'Варите до мягкости, затем проверьте соль.',
    ],
  ),
  Recipe(
    id: 'salmon-potato',
    title: 'Лосось с картофелем и брокколи',
    kind: 'ужин',
    minutes: 32,
    calories: 680,
    protein: 42,
    tags: ['восстановление', 'омега-3', 'после тренировки'],
    ingredients: ['лосось', 'картофель', 'брокколи', 'лимон', 'укроп'],
    steps: [
      'Запеките картофель и лосось на одном противне.',
      'Брокколи приготовьте на пару.',
      'Добавьте лимон и укроп перед подачей.',
    ],
  ),
  Recipe(
    id: 'cottage-cheese-bowl',
    title: 'Творожная миска с фруктами',
    kind: 'перекус',
    minutes: 7,
    calories: 310,
    protein: 30,
    tags: ['белок', 'без плиты', 'после тренировки'],
    ingredients: ['творог', 'банан', 'ягоды', 'семена чиа'],
    steps: [
      'Смешайте творог с ягодами.',
      'Добавьте половину банана и семена.',
      'При непереносимости лактозы замените на безлактозный вариант.',
    ],
  ),
  Recipe(
    id: 'turkey-wrap',
    title: 'Ролл с индейкой и хумусом',
    kind: 'обед',
    minutes: 10,
    calories: 520,
    protein: 36,
    tags: ['дорога', 'без разогрева', 'баланс'],
    ingredients: ['тортилья', 'индейка', 'хумус', 'салат', 'огурец'],
    steps: [
      'Смажьте тортилью хумусом.',
      'Добавьте индейку и овощи.',
      'Сверните плотно и разрежьте пополам.',
    ],
  ),
  Recipe(
    id: 'tofu-rice',
    title: 'Тофу с рисом и овощами',
    kind: 'ужин',
    minutes: 25,
    calories: 560,
    protein: 29,
    tags: ['растительный белок', 'азиатский стиль', 'сытно'],
    ingredients: ['тофу', 'рис', 'морковь', 'перец', 'соевый соус'],
    steps: [
      'Обсушите тофу и обжарьте кубиками.',
      'Добавьте овощи и немного соуса.',
      'Подавайте с рисом и зелёным луком.',
    ],
  ),
  Recipe(
    id: 'egg-vegetable-omelet',
    title: 'Омлет с овощами и сыром',
    kind: 'завтрак',
    minutes: 14,
    calories: 370,
    protein: 28,
    tags: ['низкоуглеводно', 'быстро', 'сытость'],
    ingredients: ['яйца', 'перец', 'шпинат', 'сыр', 'томаты'],
    steps: [
      'Слегка припустите овощи.',
      'Влейте яйца и готовьте под крышкой.',
      'Добавьте сыр в конце.',
    ],
  ),
  Recipe(
    id: 'recovery-smoothie',
    title: 'Восстановительный смузи',
    kind: 'перекус',
    minutes: 6,
    calories: 340,
    protein: 26,
    tags: ['после тренировки', 'быстро', 'мягкая еда'],
    ingredients: ['кефир', 'банан', 'протеин', 'ягоды', 'овсянка'],
    steps: [
      'Сложите ингредиенты в блендер.',
      'Взбейте до однородности.',
      'При чувствительности к молочным продуктам используйте растительный напиток.',
    ],
  ),
  Recipe(
    id: 'hotel-breakfast-plate',
    title: 'Тарелка для завтрака в отеле',
    kind: 'завтрак',
    minutes: 5,
    calories: 520,
    protein: 32,
    tags: ['командировка', 'без кухни', 'контроль выбора'],
    ingredients: ['яйца', 'йогурт', 'фрукты', 'цельнозерновой хлеб', 'овощи'],
    steps: [
      'Начните с белка: яйца или йогурт.',
      'Добавьте овощи и один фрукт.',
      'Сладкую выпечку оставьте как маленькое дополнение, не основу.',
    ],
  ),
  Recipe(
    id: 'sick-day-broth',
    title: 'Лёгкий бульон с рисом',
    kind: 'восстановление',
    minutes: 30,
    calories: 280,
    protein: 18,
    tags: ['болею', 'мягко', 'гидратация'],
    ingredients: ['куриный бульон', 'рис', 'морковь', 'зелень'],
    steps: [
      'Сварите рис в бульоне до мягкости.',
      'Добавьте морковь и зелень.',
      'Ешьте небольшими порциями и следите за самочувствием.',
    ],
  ),
];
