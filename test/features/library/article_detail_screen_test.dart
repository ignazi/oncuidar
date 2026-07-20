import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/library/article_detail_screen.dart';

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

  Widget buildArticleDetail(ProviderContainer container, {String id = 'art1'}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: ArticleDetailScreen(id: id)),
      ),
    );
  }

  Future<void> seedArticle({
    required String id,
    required String title,
    required String category,
    required String topic,
    required String body,
    String? imageUrl,
  }) async {
    await fakeFirestore.collection('educationalContent').doc(id).set({
      'title': title,
      'category': category,
      'topic': topic,
      'body': body,
      'imageUrl': ?imageUrl,
      'createdAt': DateTime(2024, 5, 1),
    });
  }

  group('ArticleDetailScreen — E.4: Load article by ID', () {
    testWidgets('loads and displays article content', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedArticle(
        id: 'art1',
        title: 'Cuidados durante quimioterapia',
        category: 'Guías',
        topic: 'Nutrición',
        body: 'Es importante mantener una buena hidratación durante el tratamiento.',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildArticleDetail(container, id: 'art1'));
      await tester.pumpAndSettle();

      expect(find.text('Cuidados durante quimioterapia'), findsOneWidget);
      expect(
        find.text(
            'Es importante mantener una buena hidratación durante el tratamiento.'),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator while loading', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildArticleDetail(container, id: 'art1'));
      // Don't pumpAndSettle - check for CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows not found message for nonexistent article',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildArticleDetail(container, id: 'nonexistent'));
      await tester.pumpAndSettle();

      expect(find.text('Artículo no encontrado'), findsOneWidget);
    });
  });

  group('ArticleDetailScreen — E.5: Bookmark toggle', () {
    testWidgets('tapping bookmark toggles favorite in Firestore',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedArticle(
        id: 'art1',
        title: 'Guía de nutrición',
        category: 'Guías',
        topic: 'Nutrición',
        body: 'Contenido...',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildArticleDetail(container, id: 'art1'));
      await tester.pumpAndSettle();

      // Find and tap the bookmark icon
      final bookmarkIcon = find.byIcon(Icons.bookmark_border);
      expect(bookmarkIcon, findsOneWidget);
      await tester.tap(bookmarkIcon);
      await tester.pumpAndSettle();

      // Favorites are now stored at USER level, not patient level
      final userDoc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .get();

      final favorites =
          List<String>.from(userDoc.data()?['favoriteArticles'] ?? []);
      expect(favorites, contains('art1'));

      // Verify icon changed to bookmark
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
    });

    testWidgets('tapping again removes from favorites', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await seedArticle(
        id: 'art1',
        title: 'Guía de nutrición',
        category: 'Guías',
        topic: 'Nutrición',
        body: 'Contenido...',
      );

      // Pre-set article as favorite at USER level
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .set({'favoriteArticles': ['art1']}, SetOptions(merge: true));

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildArticleDetail(container, id: 'art1'));
      await tester.pumpAndSettle();

      // Should show filled bookmark
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      // Tap to remove
      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      // Verify removed from Firestore (user level)
      final userDoc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .get();

      final favorites =
          List<String>.from(userDoc.data()?['favoriteArticles'] ?? []);
      expect(favorites, isNot(contains('art1')));

      // Verify icon changed back
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });
  });
}
