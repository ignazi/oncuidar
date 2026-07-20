import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/library/library_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService testService;
  const testUid = 'test-uid-123';
  const testPatientId = 'patient-1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  Widget buildLibrary(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: LibraryScreen()),
      ),
    );
  }

  Future<void> seedPatient() async {
    await fakeFirestore
        .collection('users')
        .doc(testUid)
        .collection('patients')
        .doc(testPatientId)
        .set({
      'fullName': 'Lucas García',
      'diagnosis': 'Leucemia',
      'caregiverId': testUid,
      'createdAt': DateTime(2024, 2, 1),
    });
  }

  Future<void> seedArticle({
    required String id,
    required String title,
    required String category,
    required String topic,
    required String body,
  }) async {
    await fakeFirestore.collection('educationalContent').doc(id).set({
      'title': title,
      'category': category,
      'topic': topic,
      'body': body,
      'createdAt': DateTime(2024, 5, 1),
    });
  }

  group('LibraryScreen — E.1: StreamProvider integration', () {
    testWidgets('shows real articles from educationalContentProvider',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedPatient();
      await seedArticle(
        id: 'art1',
        title: 'Cuidados durante quimioterapia',
        category: 'Guías',
        topic: 'Nutrición',
        body: 'Contenido completo...',
      );
      await seedArticle(
        id: 'art2',
        title: 'Hidratación y alimentación',
        category: 'PDFs',
        topic: 'Nutrición',
        body: 'Guía práctica...',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildLibrary(container));
      await tester.pumpAndSettle();

      expect(find.text('Cuidados durante quimioterapia'), findsOneWidget);
      expect(find.text('Hidratación y alimentación'), findsOneWidget);
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildLibrary(container));
      // Don't pumpAndSettle - check for CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('LibraryScreen — E.2: Category filter', () {
    testWidgets('category chip filters articles', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedPatient();
      await seedArticle(
        id: 'art1',
        title: 'Guía de nutrición',
        category: 'Guías',
        topic: 'Nutrición',
        body: 'Contenido...',
      );
      await seedArticle(
        id: 'art2',
        title: 'Video de ejercicios',
        category: 'Videos',
        topic: 'Ejercicio',
        body: 'Contenido...',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildLibrary(container));
      await tester.pumpAndSettle();

      // Tap Guías filter chip — note: 'Guías' filter also shows PDFs and
      // Infografías, so we use a 'Videos' category article to test filtering
      await tester.tap(find.text('Guías').first);
      await tester.pumpAndSettle();

      expect(find.text('Guía de nutrición'), findsOneWidget);
      expect(find.text('Video de ejercicios'), findsNothing);
    });

    testWidgets('Todos chip shows all articles', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedPatient();
      await seedArticle(
        id: 'art1',
        title: 'Guía de nutrición',
        category: 'Guías',
        topic: 'Nutrición',
        body: 'Contenido...',
      );
      await seedArticle(
        id: 'art2',
        title: 'Video de ejercicios',
        category: 'Videos',
        topic: 'Ejercicio',
        body: 'Contenido...',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildLibrary(container));
      await tester.pumpAndSettle();

      // First filter, then back to Todos
      await tester.tap(find.text('Guías').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      expect(find.text('Guía de nutrición'), findsOneWidget);
      expect(find.text('Video de ejercicios'), findsOneWidget);
    });
  });

  group('LibraryScreen — E.3: Bookmark toggle', () {
    testWidgets('tapping bookmark toggles favorite in Firestore',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedPatient();
      await seedArticle(
        id: 'art1',
        title: 'Guía de nutrición',
        category: 'Guías',
        topic: 'Nutrición',
        body: 'Contenido...',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildLibrary(container));
      await tester.pumpAndSettle();

      // Find and tap the bookmark icon for the first article
      final bookmarkIcons = find.byIcon(Icons.bookmark_border);
      expect(bookmarkIcons, findsWidgets);
      await tester.tap(bookmarkIcons.first);
      await tester.pumpAndSettle();

      // Verify Firestore was updated
      final userDoc = await fakeFirestore.collection('users').doc(testUid).get();

      final favorites =
          List<String>.from(userDoc.data()?['favoriteArticles'] ?? []);
      expect(favorites, contains('art1'));
    });
  });
}
