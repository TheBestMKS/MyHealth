import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/prescription_parser.dart';

void main() {
  group('Russian prescription parser', () {
    test('extracts multiple medicines, doses and schedules', () {
      final drafts = parsePrescriptionText('''
Пациент: Иванов И.И.
1. Амоксициллин таблетки 500 мг по 1 таблетке 3 раза в день после еды 7 дней
2. Витамин D3 капли 1000 МЕ в 09:00 курс 30 дней
''');

      expect(drafts, hasLength(2));
      expect(drafts.first.name, contains('Амоксициллин'));
      expect(drafts.first.dose, '500 мг');
      expect(drafts.first.form, 'таблетки');
      expect(drafts.first.schedule, contains('3 раза в день'));
      expect(drafts.first.foodRule, 'после еды');
      expect(drafts.first.courseDuration, '7 дней');
      expect(drafts.last.name, contains('Витамин D3'));
      expect(drafts.last.dose.toLowerCase(), '1000 ме');
      expect(drafts.last.schedule, contains('09:00'));
      expect(drafts.last.toMetadata()['candidateType'], 'prescription');
    });

    test('normalizes course dates to the visible Russian format', () {
      final draft = parsePrescriptionText(
        'Метформин таблетки 500 мг в 08:00 с 1.10.2026 по 30-10-2026',
      ).single;

      expect(draft.courseStart, '01.10.2026');
      expect(draft.courseEnd, '30.10.2026');
    });

    test('keeps uncertain plain text for mandatory manual review', () {
      final draft = parsePrescriptionText('Неясное название препарата').single;

      expect(draft.confidence, lessThan(0.5));
      expect(draft.dose, isEmpty);
      expect(draft.rawText, contains('Неясное'));
    });
  });
}
