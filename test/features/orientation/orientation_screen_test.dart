import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/orientation/orientation_screen.dart';

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
        // En tests, evitamos cargar el asset bundle; usamos Firestore directamente
        orientationRulesProvider.overrideWith(
          (ref) => ref.watch(firestoreServiceProvider).orientationRulesStream(),
        ),
      ],
    );
  }

  Widget buildOrientation(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/orientation',
          routes: [
            GoRoute(
              path: '/orientation',
              builder: (_, _) => const OrientationScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addRule({
    required String id,
    required String category,
    required String subQuestion,
    required String answer,
    required String alertLevel,
    List<String> tags = const [],
  }) async {
    await fakeFirestore.collection('orientationRules').doc(id).set({
      'category': category,
      'subQuestion': subQuestion,
      'answer': answer,
      'alertLevel': alertLevel,
      'tags': tags,
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('OrientationScreen — D.3: StreamProvider integration', () {
    testWidgets('shows suggestions from orientationRulesProvider',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addRule(
        id: 'r1',
        category: 'Fiebre',
        subQuestion: '¿Qué hago si tiene fiebre?',
        answer: 'Si la temperatura es >= 38°C, contacta al equipo médico.',
        alertLevel: 'yellow',
        tags: ['fiebre', 'temperatura', 'calentura'],
      );
      await addRule(
        id: 'r2',
        category: 'Vómitos',
        subQuestion: '¿Qué hago si vomita?',
        answer: 'Ofrece pequeños sorbos de agua.',
        alertLevel: 'yellow',
        tags: ['vomito', 'vomitar'],
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildOrientation(container));
      await settle(tester);

      expect(find.text('¿Qué hago si tiene fiebre?'), findsOneWidget);
      expect(find.text('¿Qué hago si vomita?'), findsOneWidget);
    });

    testWidgets('tapping a suggestion shows the answer as bot response',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addRule(
        id: 'r1',
        category: 'Fiebre',
        subQuestion: '¿Qué hago si tiene fiebre?',
        answer: 'Si la temperatura es >= 38°C, contacta al equipo médico.',
        alertLevel: 'yellow',
        tags: ['fiebre'],
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildOrientation(container));
      await settle(tester);

      await tester.tap(find.text('¿Qué hago si tiene fiebre?'));
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);

      expect(find.text('Si la temperatura es >= 38°C, contacta al equipo médico.'), findsOneWidget);
    });
  });

  group('OrientationScreen — D.4: Tag/keyword matching', () {
    testWidgets('typing a keyword matches rules by tags', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addRule(
        id: 'r1',
        category: 'Fiebre',
        subQuestion: '¿Qué hago si tiene fiebre?',
        answer: 'Respuesta sobre fiebre.',
        alertLevel: 'yellow',
        tags: ['fiebre', 'temperatura'],
      );
      await addRule(
        id: 'r2',
        category: 'Vómitos',
        subQuestion: '¿Qué hago si vomita?',
        answer: 'Respuesta sobre vómitos.',
        alertLevel: 'yellow',
        tags: ['vomito'],
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildOrientation(container));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'fiebre');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);

      expect(find.text('Respuesta sobre fiebre.'), findsOneWidget);
      expect(find.text('Respuesta sobre vómitos.'), findsNothing);
    });

    testWidgets('typing a keyword matches rules by category', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addRule(
        id: 'r1',
        category: 'Fiebre',
        subQuestion: '¿Qué hago si tiene fiebre?',
        answer: 'Respuesta fiebre.',
        alertLevel: 'yellow',
        tags: ['calentura'],
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildOrientation(container));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'Fiebre');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);

      expect(find.text('Respuesta fiebre.'), findsOneWidget);
    });

    testWidgets('no match shows fallback message', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addRule(
        id: 'r1',
        category: 'Fiebre',
        subQuestion: '¿Qué hago si tiene fiebre?',
        answer: 'Respuesta fiebre.',
        alertLevel: 'yellow',
        tags: ['fiebre'],
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildOrientation(container));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'astronave');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);

      expect(find.textContaining('No encontré'), findsOneWidget);
    });

    testWidgets('matching is case-insensitive', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await addRule(
        id: 'r1',
        category: 'Fiebre',
        subQuestion: '¿Qué hago si tiene fiebre?',
        answer: 'Respuesta fiebre.',
        alertLevel: 'yellow',
        tags: ['fiebre'],
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildOrientation(container));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'FIEBRE');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);

      expect(find.text('Respuesta fiebre.'), findsOneWidget);
    });
  });

  group('OrientationScreen — D.5: Header buttons', () {
    testWidgets('search and new chat buttons are in header', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildOrientation(container));
      await settle(tester);

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}
