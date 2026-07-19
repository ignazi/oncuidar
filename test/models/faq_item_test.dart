import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/models/faq_item.dart';

void main() {
  group('FaqItem', () {
    group('fromMap', () {
      test('creates FaqItem from valid map', () {
        final map = {
          'question': '¿Qué es quimioterapia?',
          'answer': 'Es un tratamiento que usa medicamentos.',
          'category': 'Tratamiento',
        };

        final item = FaqItem.fromMap('faq1', map);

        expect(item.id, 'faq1');
        expect(item.question, '¿Qué es quimioterapia?');
        expect(item.answer, 'Es un tratamiento que usa medicamentos.');
        expect(item.category, 'Tratamiento');
      });

      test('handles missing optional fields with defaults', () {
        final map = <String, dynamic>{
          'question': 'Test question',
        };

        final item = FaqItem.fromMap('faq2', map);

        expect(item.id, 'faq2');
        expect(item.question, 'Test question');
        expect(item.answer, '');
        expect(item.category, '');
      });

      test('handles all fields provided', () {
        final map = {
          'question': 'Pregunta completa',
          'answer': 'Respuesta completa',
          'category': 'Nutrición',
        };

        final item = FaqItem.fromMap('faq3', map);

        expect(item.id, 'faq3');
        expect(item.question, 'Pregunta completa');
        expect(item.answer, 'Respuesta completa');
        expect(item.category, 'Nutrición');
      });
    });

    group('toMap', () {
      test('converts FaqItem to map', () {
        final item = FaqItem(
          id: 'faq1',
          question: '¿Qué es quimioterapia?',
          answer: 'Es un tratamiento.',
          category: 'Tratamiento',
        );

        final map = item.toMap();

        expect(map['question'], '¿Qué es quimioterapia?');
        expect(map['answer'], 'Es un tratamiento.');
        expect(map['category'], 'Tratamiento');
      });

      test('toMap does not include id', () {
        final item = FaqItem(
          id: 'faq1',
          question: 'Test',
          answer: 'Answer',
          category: 'Cat',
        );

        final map = item.toMap();

        expect(map.containsKey('id'), false);
      });
    });

    group('round-trip', () {
      test('fromMap(toMap) preserves data', () {
        final original = FaqItem(
          id: 'faq1',
          question: '¿Cómo prevenir infecciones?',
          answer: 'Lavarse las manos frecuentemente.',
          category: 'Prevención',
        );

        final map = original.toMap();
        final restored = FaqItem.fromMap(original.id, map);

        expect(restored.id, original.id);
        expect(restored.question, original.question);
        expect(restored.answer, original.answer);
        expect(restored.category, original.category);
      });
    });
  });
}
