class PrescriptionDraft {
  const PrescriptionDraft({
    required this.name,
    required this.dose,
    required this.form,
    required this.schedule,
    required this.foodRule,
    required this.courseDuration,
    required this.courseStart,
    required this.courseEnd,
    required this.rawText,
    required this.confidence,
  });

  final String name;
  final String dose;
  final String form;
  final String schedule;
  final String foodRule;
  final String courseDuration;
  final String courseStart;
  final String courseEnd;
  final String rawText;
  final double confidence;

  Map<String, String> toMetadata() => {
    'candidateType': 'prescription',
    'name': name,
    'dose': dose,
    'form': form,
    'schedule': schedule,
    'foodRule': foodRule,
    'courseDuration': courseDuration,
    'courseStart': courseStart,
    'courseEnd': courseEnd,
    'rawText': rawText,
  };
}

List<PrescriptionDraft> parsePrescriptionText(String source) {
  final normalized = source
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'\n+'), '\n')
      .trim();
  if (normalized.isEmpty) return const [];
  final lines = normalized
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final blocks = <String>[];
  var current = StringBuffer();
  for (final line in lines) {
    if (_ignoreLine(line)) continue;
    final startsItem = RegExp(
      r'^(?:\d{1,2}\s*[\).:-]\s*|[-•]\s+|rp\.?\s*)',
      caseSensitive: false,
    ).hasMatch(line);
    final hasDose = _dosePattern.hasMatch(line);
    if (current.isNotEmpty &&
        (startsItem || hasDose && _dosePattern.hasMatch('$current'))) {
      blocks.add(current.toString().trim());
      current = StringBuffer();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(line);
  }
  if (current.isNotEmpty) blocks.add(current.toString().trim());

  final drafts = blocks
      .map(_parseBlock)
      .whereType<PrescriptionDraft>()
      .toList(growable: false);
  if (drafts.isNotEmpty) return drafts;

  final fallback = lines.firstWhere(
    (line) => !_ignoreLine(line),
    orElse: () => '',
  );
  if (fallback.isEmpty) return const [];
  return [
    PrescriptionDraft(
      name: _cleanName(fallback),
      dose: '',
      form: _detectForm(normalized),
      schedule: '',
      foodRule: _foodRule(normalized),
      courseDuration: _courseDuration(normalized),
      courseStart: '',
      courseEnd: '',
      rawText: normalized,
      confidence: 0.25,
    ),
  ];
}

final _dosePattern = RegExp(
  r'\d+(?:[\.,]\d+)?\s*(?:мкг|мг|г|мл|ед\.?|ме|iu|mcg|mg|ml)(?![a-zа-яё])',
  caseSensitive: false,
);

PrescriptionDraft? _parseBlock(String raw) {
  final cleaned = raw
      .replaceFirst(
        RegExp(
          r'^(?:\d{1,2}\s*[\).:-]\s*|[-•]\s+|rp\.?\s*)',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  final doseMatch = _dosePattern.firstMatch(cleaned);
  final formMatch = RegExp(
    r'(?:таблетк[а-яё]*|капсул[а-яё]*|раствор[а-яё]*|сироп[а-яё]*|суспензи[а-яё]*|'
    r'капл[а-яё]*|спре[а-яё]*|маз[а-яё]*|крем[а-яё]*|свеч[а-яё]*|суппозитор[а-яё]*|'
    r'инъекц[а-яё]*|ампул[а-яё]*|ингалятор[а-яё]*|порош[а-яё]*)',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (doseMatch == null && formMatch == null) return null;
  final boundary = doseMatch?.start ?? formMatch!.start;
  final name = _cleanName(cleaned.substring(0, boundary));
  if (name.length < 2 || _ignoreLine(name)) return null;

  final dose = doseMatch?.group(0)?.replaceAll(',', '.') ?? '';
  final lower = cleaned.toLowerCase();
  final scheduleParts = <String>[];
  final frequency = RegExp(
    r'(?:по\s+[^.;,]{0,25}\s+)?\d+\s*раз(?:а|у|)\s+(?:в|за)\s+(?:день|сутки)',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (frequency != null) scheduleParts.add(frequency.group(0)!);
  final every = RegExp(
    r'(?:каждые|через)\s+\d+\s*(?:час\w*|дн\w*)',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (every != null) scheduleParts.add(every.group(0)!);
  final times = RegExp(r'\b(?:[01]?\d|2[0-3])[:\.]\d{2}\b')
      .allMatches(cleaned)
      .map((match) => match.group(0)!.replaceAll('.', ':'))
      .toList();
  if (times.isNotEmpty) scheduleParts.add('в ${times.join(', ')}');
  for (final marker in const ['утром', 'днём', 'вечером', 'на ночь']) {
    if (lower.contains(marker)) scheduleParts.add(marker);
  }
  final courseDuration = _courseDuration(cleaned);
  if (courseDuration.isNotEmpty) scheduleParts.add('курс $courseDuration');
  final dates = RegExp(r'\b\d{1,2}[\.-]\d{1,2}[\.-]\d{4}\b')
      .allMatches(cleaned)
      .map((match) => _normalizeDate(match.group(0)!))
      .toList();
  var confidence = 0.35;
  if (dose.isNotEmpty) confidence += 0.25;
  if (scheduleParts.isNotEmpty) confidence += 0.2;
  if (formMatch != null) confidence += 0.1;

  return PrescriptionDraft(
    name: name,
    dose: dose,
    form: _detectForm(cleaned),
    schedule: scheduleParts.toSet().join('; '),
    foodRule: _foodRule(cleaned),
    courseDuration: courseDuration,
    courseStart: dates.isEmpty ? '' : dates.first,
    courseEnd: dates.length < 2 ? '' : dates[1],
    rawText: raw,
    confidence: confidence.clamp(0, 0.95),
  );
}

bool _ignoreLine(String line) {
  final lower = line.toLowerCase().trim();
  return lower.isEmpty ||
      lower.startsWith('пациент') ||
      lower.startsWith('дата рожд') ||
      lower.startsWith('врач') ||
      lower.startsWith('медицинск') ||
      lower.startsWith('диагноз') ||
      lower == 'рецепт' ||
      lower.startsWith('подпись') ||
      lower.startsWith('печать');
}

String _cleanName(String value) {
  return value
      .replaceAll(RegExp(r'^[^a-zа-яё]+', caseSensitive: false), '')
      .replaceAll(
        RegExp(r'\b(?:tab|caps|sol|d\.s\.)\.?$', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _detectForm(String text) {
  final lower = text.toLowerCase();
  const forms = <String, List<String>>{
    'таблетки': ['таблет', 'tab'],
    'капсулы': ['капсул', 'caps'],
    'раствор': ['раствор', 'sol'],
    'сироп': ['сироп'],
    'суспензия': ['суспен'],
    'капли': ['капл'],
    'спрей': ['спрей'],
    'мазь': ['мазь'],
    'крем': ['крем'],
    'суппозитории': ['свеч', 'суппозитор'],
    'инъекция': ['инъек', 'ампул'],
    'ингалятор': ['ингалятор'],
    'порошок': ['порош'],
  };
  for (final entry in forms.entries) {
    if (entry.value.any(lower.contains)) return entry.key;
  }
  return '';
}

String _foodRule(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('до ед') || lower.contains('натощак')) {
    return 'до еды';
  }
  if (lower.contains('после ед')) return 'после еды';
  if (lower.contains('во время ед') || lower.contains('с ед')) {
    return 'во время еды';
  }
  return '';
}

String _courseDuration(String text) {
  final match = RegExp(
    r'\d+\s*(?:дн(?:я|ей|ь)?|сут(?:ок|ки)?|недел[а-яё]*|месяц[а-яё]*)(?![а-яё])',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(0) ?? '';
}

String _normalizeDate(String value) {
  final parts = value.split(RegExp(r'[\.-]'));
  if (parts.length != 3) return value;
  return '${parts[0].padLeft(2, '0')}.${parts[1].padLeft(2, '0')}.${parts[2]}';
}
