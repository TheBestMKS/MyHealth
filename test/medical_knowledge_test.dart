import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/medical_knowledge.dart';

void main() {
  test('merges curated Russian cards with MedlinePlus topics', () {
    final catalog = parseMedicalKnowledgeCatalog({
      'ru': '''
        {
          "updated": "2026-09-23",
          "conditions": [{
            "id": "asthma-ru",
            "title": "Астма",
            "titleEn": "Asthma",
            "category": "Дыхательная система",
            "summary": "Справочная карточка.",
            "symptoms": ["свистящее дыхание"],
            "care": "Следовать плану врача.",
            "urgent": "Срочная помощь при тяжёлой одышке.",
            "prevention": "Избегать триггеров.",
            "aliases": ["бронхиальная астма"],
            "sourceUrl": "https://medlineplus.gov/asthma.html"
          }],
          "substances": [{
            "id": "vitamin-d",
            "title": "Витамин D",
            "titleEn": "Vitamin D",
            "category": "витамин",
            "purpose": "Обмен кальция.",
            "warnings": "Учитывать назначения врача.",
            "interactions": "Возможны взаимодействия.",
            "frequencyNote": "По назначению.",
            "sourceUrl": "https://ods.od.nih.gov/"
          }]
        }
      ''',
      'medlineplus': '''
        {
          "attribution": "MedlinePlus, U.S. National Library of Medicine",
          "topics": [
            {"id":"asthma-en","title":"Asthma","groups":["Lungs"],"summary":"Duplicate English card.","aliases":[],"url":"https://medlineplus.gov/asthma.html","source":"MedlinePlus","language":"en"},
            {"id":"migraine","title":"Migraine","groups":["Neurologic"],"summary":"Headache topic.","aliases":["Migraine headache"],"url":"https://medlineplus.gov/migraine.html","source":"MedlinePlus","language":"en"}
          ]
        }
      ''',
      'openfda': '''
        {
          "substances": [
            {"id":"duplicate","title":"Vitamin D","titleEn":"Vitamin D","category":"FDA","purpose":"Duplicate","warnings":"","interactions":"","frequencyNote":"","sourceUrl":"https://open.fda.gov/"},
            {"id":"metformin","title":"METFORMIN","titleEn":"METFORMIN","category":"FDA","purpose":"Active ingredient listing","warnings":"Check label","interactions":"Check interactions","frequencyNote":"Use prescription","sourceUrl":"https://open.fda.gov/"}
          ]
        }
      ''',
    });

    expect(catalog.topics, hasLength(2));
    expect(catalog.topics.first.titleRu, 'Астма');
    expect(catalog.topics.last.titleEn, 'Migraine');
    expect(catalog.substances, hasLength(2));
    expect(catalog.substances.first.title, 'Витамин D');
    expect(catalog.substances.last.title, 'METFORMIN');
    expect(catalog.attribution, contains('MedlinePlus'));
  });

  testWidgets('bundles large offline condition and medicine catalogs', (
    tester,
  ) async {
    final catalog = await tester.runAsync(
      () => MedicalKnowledgeRepository.instance.load(),
    );

    expect(catalog, isNotNull);
    expect(catalog!.topics.length, greaterThanOrEqualTo(1000));
    expect(catalog.substances.length, greaterThanOrEqualTo(3200));
    expect(
      catalog.substances.any(
        (item) => item.category.toLowerCase().contains('витамин'),
      ),
      isTrue,
    );
    expect(
      catalog.substances.any((item) => item.id.startsWith('openfda-ndc-')),
      isTrue,
    );
  });
}
