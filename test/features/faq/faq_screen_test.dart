import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/faq/faq_screen.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService testService;
  const testUid = 'test-uid-123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    testService =
        FirestoreService(db: fakeFirestore, auth: mockAuth, testUid: testUid);
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        firestoreServiceProvider.overrideWithValue(testService),
      ],
    );
  }

  Widget buildFaq(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: FAQScreen()),
      ),
    );
  }

  Future<void> addFaq({
    required String id,
    required String question,
    required String answer,
    required String category,
  }) async {
    await fakeFirestore.collection('faqs').doc(id).set({
      'question': question,
      'answer': answer,
      'category': category,
    });
  }

  group('FAQScreen — D.1: StreamProvider integration', () {
    testWidgets('shows real FAQs from faqsProvider', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addFaq(
        id: 'f1',
        question: '¿Qué temperatura se considera fiebre?',
        answer: 'Se considera fiebre cuando la temperatura corporal es igual o superior a 38°C.',
        category: 'Fiebre',
      );
      await addFaq(
        id: 'f2',
        question: '¿Cómo administro los medicamentos?',
        answer: 'Sigue siempre las indicaciones del médico.',
        category: 'Medicamentos',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué temperatura se considera fiebre?'), findsOneWidget);
      expect(find.text('¿Cómo administro los medicamentos?'), findsOneWidget);
    });

    testWidgets('search filters FAQs by question text', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addFaq(
        id: 'f1',
        question: '¿Qué temperatura se considera fiebre?',
        answer: 'Se considera fiebre cuando la temperatura corporal es igual o superior a 38°C.',
        category: 'Fiebre',
      );
      await addFaq(
        id: 'f2',
        question: '¿Cómo administro los medicamentos?',
        answer: 'Sigue siempre las indicaciones del médico.',
        category: 'Medicamentos',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'temperatura');
      await tester.pumpAndSettle();

      expect(find.text('¿Qué temperatura se considera fiebre?'), findsOneWidget);
      expect(find.text('¿Cómo administro los medicamentos?'), findsNothing);
    });

    testWidgets('category chip filters FAQs', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addFaq(
        id: 'f1',
        question: '¿Qué temperatura se considera fiebre?',
        answer: 'Se considera fiebre.',
        category: 'Fiebre',
      );
      await addFaq(
        id: 'f2',
        question: '¿Cómo administro los medicamentos?',
        answer: 'Sigue las indicaciones.',
        category: 'Medicamentos',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      // Tap "Fiebre" category chip — use .first since the category name
      // also appears on the FAQ item itself
      await tester.tap(find.text('Fiebre').first);
      await tester.pumpAndSettle();

      expect(find.text('¿Qué temperatura se considera fiebre?'), findsOneWidget);
      expect(find.text('¿Cómo administro los medicamentos?'), findsNothing);
    });

    testWidgets('category chip "Todas" shows all FAQs', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addFaq(
        id: 'f1',
        question: '¿Qué temperatura?',
        answer: 'Respuesta.',
        category: 'Fiebre',
      );
      await addFaq(
        id: 'f2',
        question: '¿Qué medicamentos?',
        answer: 'Respuesta.',
        category: 'Medicamentos',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      // First tap Fiebre, then Todas — use .first for chip taps
      await tester.tap(find.text('Fiebre').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué temperatura?'), findsOneWidget);
      expect(find.text('¿Qué medicamentos?'), findsOneWidget);
    });

    testWidgets('categories are derived from Firestore data', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addFaq(
        id: 'f1',
        question: 'Pregunta?',
        answer: 'Respuesta.',
        category: 'Higiene',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      // "Todas" chip appears once; "Higiene" appears as chip AND as
      // category label on the FAQ item, so use findsWidgets
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Higiene'), findsWidgets);
    });
  });

  group('FAQScreen — D.2: Empty state', () {
    testWidgets('shows empty state when no FAQs exist', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // faqsProvider yields defaultFaqItems first, so we must override it
      // to return an empty list to actually test the empty state
      final container = ProviderContainer(
        overrides: [
          firestoreServiceProvider.overrideWithValue(testService),
          faqsProvider.overrideWithValue(const AsyncData([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      expect(find.text('No hay preguntas frecuentes disponibles.'), findsOneWidget);
    });

    testWidgets('does not show empty state when FAQs exist', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addFaq(
        id: 'f1',
        question: '¿Pregunta?',
        answer: 'Respuesta.',
        category: 'Test',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      expect(find.text('No hay preguntas frecuentes disponibles.'), findsNothing);
    });
  });

  group('FAQScreen — Tapping FAQ expands answer', () {
    testWidgets('tapping a FAQ item shows its answer', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addFaq(
        id: 'f1',
        question: '¿Pregunta?',
        answer: 'Esta es la respuesta completa.',
        category: 'Test',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildFaq(container));
      await tester.pumpAndSettle();

      // Answer should not be visible initially
      expect(find.text('Esta es la respuesta completa.'), findsNothing);

      // Tap the question to expand
      await tester.tap(find.text('¿Pregunta?'));
      await tester.pumpAndSettle();

      // Answer should now be visible
      expect(find.text('Esta es la respuesta completa.'), findsOneWidget);
    });
  });
}
