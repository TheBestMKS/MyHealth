import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/model.dart';

void main() {
  test(
    'persists expanded medical, document, medication and assistant data',
    () {
      final state = HealthAppState.seed().copyWith(
        settings: const AppSettings().copyWith(
          unitSystem: 'mixed',
          dateDisplayFormat: 'dd.mm.yyyy',
          timeFormat: '24h',
          distanceUnit: 'km',
          temperatureUnit: 'celsius',
          bodyWeightUnit: 'kg',
          compactMode: false,
          backgroundAnalysisEnabled: true,
          launchAtStartup: true,
          confirmBeforeExit: false,
        ),
        careProviders: const [
          CareProvider(
            id: 'doctor-1',
            name: 'Dr Smith',
            role: 'doctor',
            specialty: 'cardiology',
            clinic: 'City clinic',
            phone: '+100',
            address: 'Main street',
            notes: 'annual checks',
          ),
        ],
        medicalEvents: const [
          MedicalEvent(
            id: 'event-1',
            title: 'Knee surgery',
            date: '2026-01-02',
            kind: 'operation',
            severity: 'medium',
            provider: 'Dr Smith',
            bodyArea: 'knee',
            linkedDocumentId: 'doc-1',
            notes: 'rehab required',
          ),
        ],
        medications: const [
          Medication(
            id: 'med-1',
            name: 'Magnesium',
            dose: '200 mg',
            schedule: 'evening',
            takenToday: false,
            notes: 'after dinner',
            form: 'tablet',
            courseStart: '2026-01-01',
            courseEnd: '2026-01-31',
            foodRule: 'after food',
            prescribingDoctor: 'Dr Smith',
            linkedCondition: 'sleep',
            remainingUnits: 4,
            lowStockThreshold: 5,
            sideEffects: 'none noted',
            purchaseReminder: true,
          ),
        ],
        documents: const [
          HealthDocument(
            id: 'doc-1',
            title: 'Lab report',
            kind: 'lab',
            date: '2026-01-02',
            locked: true,
            notes: 'reviewed',
            filePath: 'docs/lab.pdf',
            tags: ['lab', 'cardio'],
            linkedCondition: 'sleep',
            linkedMedicationId: 'med-1',
            linkedDoctor: 'Dr Smith',
            searchText: 'hemoglobin normal',
          ),
        ],
        assistantMessages: const [
          AssistantMessage(
            id: 'msg-1',
            createdAt: '2026-01-02T10:00:00',
            role: 'user',
            text: 'Голосовое сообщение',
            relatedSection: 'today',
            kind: 'voice',
            transcript: 'Выпил 250 мл воды',
            attachmentPath: 'media/voice-1.m4a',
            attachmentName: 'voice-1.m4a',
            mimeType: 'audio/mp4',
            analysis: 'Распознан русский текст',
            actionSummary: 'Вода добавлена',
            durationSeconds: 7,
          ),
        ],
      );

      final restored = HealthAppState.fromJson(state.toJson());

      expect(restored.settings.unitSystem, 'mixed');
      expect(restored.settings.compactMode, isFalse);
      expect(restored.settings.backgroundAnalysisEnabled, isTrue);
      expect(restored.settings.launchAtStartup, isTrue);
      expect(restored.settings.confirmBeforeExit, isFalse);
      expect(restored.careProviders.single.clinic, 'City clinic');
      expect(restored.medicalEvents.single.bodyArea, 'knee');
      expect(restored.medications.single.stockIsLow, isTrue);
      expect(restored.documents.single.tags, contains('cardio'));
      expect(restored.assistantMessages.single.relatedSection, 'today');
      expect(restored.assistantMessages.single.kind, 'voice');
      expect(restored.assistantMessages.single.transcript, 'Выпил 250 мл воды');
      expect(restored.assistantMessages.single.durationSeconds, 7);
      expect(restored.assistantMessages.single.hasAttachment, isTrue);
    },
  );
}
