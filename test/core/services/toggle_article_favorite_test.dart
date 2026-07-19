import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/core/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService service;
  const testUid = 'test-uid-123';
  const testPatientId = 'patient-1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    service = FirestoreService(db: fakeFirestore, auth: mockAuth, testUid: testUid);
  });

  Future<void> seedPatient({List<String> favoriteArticles = const []}) async {
    await fakeFirestore
        .collection('users')
        .doc(testUid)
        .collection('patients')
        .doc(testPatientId)
        .set({
      'fullName': 'Lucas García',
      'diagnosis': 'Leucemia',
      'caregiverId': testUid,
      'favoriteArticles': favoriteArticles,
      'createdAt': DateTime(2024, 2, 1),
    });
  }

  group('toggleArticleFavorite', () {
    test('adds article to favorites when not already favorite', () async {
      await seedPatient();

      await service.toggleArticleFavorite(testPatientId, 'art1');

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPatientId)
          .get();

      final favorites =
          List<String>.from(doc.data()?['favoriteArticles'] ?? []);
      expect(favorites, contains('art1'));
    });

    test('removes article from favorites when already favorite', () async {
      await seedPatient(favoriteArticles: ['art1', 'art2']);

      await service.toggleArticleFavorite(testPatientId, 'art1');

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPatientId)
          .get();

      final favorites =
          List<String>.from(doc.data()?['favoriteArticles'] ?? []);
      expect(favorites, isNot(contains('art1')));
      expect(favorites, contains('art2'));
    });

    test('handles patient with no favoriteArticles field', () async {
      await seedPatient();

      await service.toggleArticleFavorite(testPatientId, 'art1');

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPatientId)
          .get();

      final favorites =
          List<String>.from(doc.data()?['favoriteArticles'] ?? []);
      expect(favorites, ['art1']);
    });

    test('toggling twice returns to original state', () async {
      await seedPatient();

      await service.toggleArticleFavorite(testPatientId, 'art1');
      await service.toggleArticleFavorite(testPatientId, 'art1');

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPatientId)
          .get();

      final favorites =
          List<String>.from(doc.data()?['favoriteArticles'] ?? []);
      expect(favorites, isEmpty);
    });
  });
}
