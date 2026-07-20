import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/core/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService service;
  const testUid = 'test-uid-123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    service = FirestoreService(
      db: fakeFirestore,
      auth: mockAuth,
      testUid: testUid,
    );
  });

  Future<void> seedUser({List<String> favoriteArticles = const []}) async {
    await fakeFirestore.collection('users').doc(testUid).set({
      'favoriteArticles': favoriteArticles,
    });
  }

  Future<List<String>> readFavorites() async {
    final doc = await fakeFirestore.collection('users').doc(testUid).get();
    return List<String>.from(doc.data()?['favoriteArticles'] ?? []);
  }

  group('toggleArticleFavorite', () {
    test('adds article to caregiver favorites when not already favorite', () async {
      await seedUser();

      await service.toggleArticleFavorite('art1');

      expect(await readFavorites(), contains('art1'));
    });

    test('removes article from caregiver favorites when already favorite', () async {
      await seedUser(favoriteArticles: ['art1', 'art2']);

      await service.toggleArticleFavorite('art1');

      final favorites = await readFavorites();
      expect(favorites, isNot(contains('art1')));
      expect(favorites, contains('art2'));
    });

    test('handles user with no favoriteArticles field', () async {
      await fakeFirestore.collection('users').doc(testUid).set({});

      await service.toggleArticleFavorite('art1');

      expect(await readFavorites(), ['art1']);
    });

    test('toggling twice returns to original state', () async {
      await seedUser();

      await service.toggleArticleFavorite('art1');
      await service.toggleArticleFavorite('art1');

      expect(await readFavorites(), isEmpty);
    });
  });
}
