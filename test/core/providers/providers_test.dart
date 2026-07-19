import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/core/providers/providers.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService testService;
  const testUid = 'test-uid-123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    testService = FirestoreService(db: fakeFirestore, auth: mockAuth, testUid: testUid);
  });

  /// Creates a container with test overrides.
  /// [selectedPatientId] overrides the persisted selection (null = no selection,
  /// which means currentPatientProvider falls back to first patient).
  ProviderContainer makeContainer({String? selectedPatientId}) {
    return ProviderContainer(
      overrides: [
        firestoreServiceProvider.overrideWithValue(testService),
        // Override the Notifier with a simple StateProvider for tests.
        // This avoids needing SharedPreferences in the test environment.
        selectedPatientIdProvider.overrideWith(() => _FakeSelectedPatient(selectedPatientId)),
      ],
    );
  }

  group('firestoreServiceProvider', () {
    test('creates a FirestoreService instance', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final service = container.read(firestoreServiceProvider);
      expect(service, isA<FirestoreService>());
    });
  });

  group('currentPatientProvider', () {
    test('emits null when no patients exist', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final sub = container.listen(currentPatientProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final value = container.read(currentPatientProvider).value;
      expect(value, isNull);
      sub.close();
    });

    test('emits first patient when no selection saved', () async {
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc('p1')
          .set({
        'fullName': 'Lucas García',
        'diagnosis': 'Leucemia',
        'caregiverId': testUid,
        'createdAt': DateTime(2024, 2, 1),
      });

      final container = makeContainer(); // no selection
      addTearDown(container.dispose);

      final sub = container.listen(currentPatientProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final value = container.read(currentPatientProvider).value;
      expect(value, isNotNull);
      expect(value!.fullName, 'Lucas García');
      sub.close();
    });

    test('emits selected patient when selection matches', () async {
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc('p1')
          .set({
        'fullName': 'Lucas García',
        'diagnosis': 'Leucemia',
        'caregiverId': testUid,
        'createdAt': DateTime(2024, 2, 1),
      });
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc('p2')
          .set({
        'fullName': 'Sofía López',
        'diagnosis': 'Tumor',
        'caregiverId': testUid,
        'createdAt': DateTime(2024, 3, 1),
      });

      final container = makeContainer(selectedPatientId: 'p2');
      addTearDown(container.dispose);

      final sub = container.listen(currentPatientProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final value = container.read(currentPatientProvider).value;
      expect(value, isNotNull);
      expect(value!.fullName, 'Sofía López');
      sub.close();
    });

    test('falls back to first patient when selected ID not in list', () async {
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc('p1')
          .set({
        'fullName': 'Lucas García',
        'diagnosis': 'Leucemia',
        'caregiverId': testUid,
        'createdAt': DateTime(2024, 2, 1),
      });

      // Selected ID 'deleted-patient' doesn't exist in the list
      final container = makeContainer(selectedPatientId: 'deleted-patient');
      addTearDown(container.dispose);

      final sub = container.listen(currentPatientProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final value = container.read(currentPatientProvider).value;
      expect(value, isNotNull);
      expect(value!.fullName, 'Lucas García'); // falls back to first
      sub.close();
    });
  });

  group('faqsProvider', () {
    test('emits faqs from Firestore', () async {
      await fakeFirestore.collection('faqs').doc('faq1').set({
        'question': '¿Qué es quimioterapia?',
        'answer': 'Es un tratamiento.',
        'category': 'Tratamiento',
      });

      final container = makeContainer();
      addTearDown(container.dispose);

      final sub = container.listen(faqsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final value = container.read(faqsProvider).value;
      expect(value, isNotNull);
      expect(value, hasLength(1));
      expect(value![0].question, '¿Qué es quimioterapia?');
      sub.close();
    });
  });

  group('orientationRulesProvider', () {
    test('emits rules from Firestore', () async {
      await fakeFirestore.collection('orientationRules').doc('rule1').set({
        'category': 'Fiebre',
        'subQuestion': '¿Qué hacer?',
        'answer': 'Dar paracetamol.',
        'alertLevel': 'yellow',
        'tags': ['fiebre'],
      });

      final container = makeContainer();
      addTearDown(container.dispose);

      final sub = container.listen(orientationRulesProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final value = container.read(orientationRulesProvider).value;
      expect(value, isNotNull);
      expect(value, hasLength(1));
      expect(value![0].subQuestion, '¿Qué hacer?');
      sub.close();
    });
  });

  group('educationalContentProvider', () {
    test('emits content from Firestore', () async {
      await fakeFirestore.collection('educationalContent').doc('art1').set({
        'title': 'Cuidados',
        'category': 'Guías',
        'topic': 'Nutrición',
        'body': 'Contenido.',
        'createdAt': DateTime(2024, 5, 1),
      });

      final container = makeContainer();
      addTearDown(container.dispose);

      final sub = container.listen(educationalContentProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final value = container.read(educationalContentProvider).value;
      expect(value, isNotNull);
      expect(value, hasLength(1));
      expect(value![0].title, 'Cuidados');
      sub.close();
    });
  });
}

/// Fake Notifier that returns a fixed value — avoids SharedPreferences in tests.
class _FakeSelectedPatient extends SelectedPatientNotifier {
  final String? _fakeId;
  _FakeSelectedPatient(this._fakeId);

  @override
  String? build() => _fakeId;
}
