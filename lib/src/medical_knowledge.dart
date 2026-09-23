import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MedicalTopic {
  const MedicalTopic({
    required this.id,
    required this.titleRu,
    required this.titleEn,
    required this.category,
    required this.summary,
    required this.symptoms,
    required this.care,
    required this.urgent,
    required this.prevention,
    required this.aliases,
    required this.sourceUrl,
    required this.source,
    required this.language,
  });

  final String id;
  final String titleRu;
  final String titleEn;
  final String category;
  final String summary;
  final List<String> symptoms;
  final String care;
  final String urgent;
  final String prevention;
  final List<String> aliases;
  final String sourceUrl;
  final String source;
  final String language;

  bool get hasRussianText => titleRu.isNotEmpty;

  String titleFor(String locale) =>
      locale.startsWith('ru') && titleRu.isNotEmpty ? titleRu : titleEn;

  String get searchText => [
    titleRu,
    titleEn,
    category,
    summary,
    ...aliases,
    ...symptoms,
  ].join(' ').toLowerCase();
}

class SubstanceKnowledge {
  const SubstanceKnowledge({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.category,
    required this.purpose,
    required this.warnings,
    required this.interactions,
    required this.frequencyNote,
    required this.sourceUrl,
  });

  final String id;
  final String title;
  final String titleEn;
  final String category;
  final String purpose;
  final String warnings;
  final String interactions;
  final String frequencyNote;
  final String sourceUrl;

  String titleFor(String locale) => locale.startsWith('ru') ? title : titleEn;

  String get searchText => [
    title,
    titleEn,
    category,
    purpose,
    warnings,
    interactions,
  ].join(' ').toLowerCase();
}

class MedicalKnowledgeCatalog {
  const MedicalKnowledgeCatalog({
    required this.topics,
    required this.substances,
    required this.attribution,
    required this.updated,
  });

  final List<MedicalTopic> topics;
  final List<SubstanceKnowledge> substances;
  final String attribution;
  final String updated;
}

class MedicalKnowledgeRepository {
  MedicalKnowledgeRepository._();

  static final instance = MedicalKnowledgeRepository._();
  Future<MedicalKnowledgeCatalog>? _catalog;

  Future<MedicalKnowledgeCatalog> load() => _catalog ??= _load();

  Future<MedicalKnowledgeCatalog> _load() async {
    final assets = await Future.wait([
      rootBundle.loadString('assets/catalog/medical_ru.json'),
      rootBundle.loadString('assets/catalog/medlineplus_topics.json'),
      rootBundle.loadString('assets/catalog/openfda_substances.json'),
    ]);
    return compute(parseMedicalKnowledgeCatalog, <String, String>{
      'ru': assets[0],
      'medlineplus': assets[1],
      'openfda': assets[2],
    });
  }
}

MedicalKnowledgeCatalog parseMedicalKnowledgeCatalog(
  Map<String, String> source,
) {
  final ru = jsonDecode(source['ru'] ?? '{}') as Map<String, dynamic>;
  final medline =
      jsonDecode(source['medlineplus'] ?? '{}') as Map<String, dynamic>;
  final openFda = jsonDecode(source['openfda'] ?? '{}') as Map<String, dynamic>;
  final topics = <MedicalTopic>[];
  final translatedEnglishTitles = <String>{};

  for (final raw in _maps(ru['conditions'])) {
    final titleEn = _text(raw['titleEn']);
    translatedEnglishTitles.add(titleEn.toLowerCase());
    topics.add(
      MedicalTopic(
        id: _text(raw['id']),
        titleRu: _text(raw['title']),
        titleEn: titleEn,
        category: _text(raw['category']),
        summary: _text(raw['summary']),
        symptoms: _strings(raw['symptoms']),
        care: _text(raw['care']),
        urgent: _text(raw['urgent']),
        prevention: _text(raw['prevention']),
        aliases: _strings(raw['aliases']),
        sourceUrl: _text(raw['sourceUrl']),
        source: 'MedlinePlus / NIH, русская редакционная карточка',
        language: 'ru',
      ),
    );
  }

  for (final raw in _maps(medline['topics'])) {
    final title = _text(raw['title']);
    if (translatedEnglishTitles.contains(title.toLowerCase())) continue;
    final groups = _strings(raw['groups']);
    topics.add(
      MedicalTopic(
        id: _text(raw['id']),
        titleRu: '',
        titleEn: title,
        category: groups.isEmpty ? 'Health topic' : groups.first,
        summary: _text(raw['summary']),
        symptoms: const [],
        care: '',
        urgent: '',
        prevention: '',
        aliases: _strings(raw['aliases']),
        sourceUrl: _text(raw['url']),
        source: _text(raw['source']),
        language: _text(raw['language']),
      ),
    );
  }

  final substances = <SubstanceKnowledge>[];
  final substanceNames = <String>{};
  for (final raw in [
    ..._maps(ru['substances']),
    ..._maps(openFda['substances']),
  ]) {
    final title = _text(raw['title']);
    final titleEn = _text(raw['titleEn']);
    final key = (titleEn.isEmpty ? title : titleEn).toLowerCase();
    if (key.isEmpty || !substanceNames.add(key)) continue;
    substances.add(
      SubstanceKnowledge(
        id: _text(raw['id']),
        title: title,
        titleEn: titleEn.isEmpty ? title : titleEn,
        category: _text(raw['category']),
        purpose: _text(raw['purpose']),
        warnings: _text(raw['warnings']),
        interactions: _text(raw['interactions']),
        frequencyNote: _text(raw['frequencyNote']),
        sourceUrl: _text(raw['sourceUrl']),
      ),
    );
  }
  topics.sort((left, right) {
    if (left.hasRussianText != right.hasRussianText) {
      return left.hasRussianText ? -1 : 1;
    }
    return left.titleEn.compareTo(right.titleEn);
  });
  return MedicalKnowledgeCatalog(
    topics: List.unmodifiable(topics),
    substances: List.unmodifiable(substances),
    attribution: _text(medline['attribution']),
    updated: _text(ru['updated']),
  );
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry('$key', value)))
      .toList(growable: false);
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Object>()
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _text(Object? value) => value == null ? '' : '$value'.trim();
