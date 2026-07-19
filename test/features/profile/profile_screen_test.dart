import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/profile/profile_screen.dart';

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

  Widget buildProfile(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/welcome',
              builder: (_, _) => const Scaffold(body: Text('welcome')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> setupData({
    String displayName = 'María García',
    String relationship = 'Madre',
    String phone = '1234567890',
    String patientName = 'Lucas García',
    int? patientAge = 8,
    String diagnosis = 'Leucemia',
  }) async {
    await fakeFirestore.collection('users').doc(testUid).set({
      'displayName': displayName,
      'relationship': relationship,
      'phone': phone,
      'createdAt': DateTime(2024, 1, 1),
    });
    await fakeFirestore
        .collection('users')
        .doc(testUid)
        .collection('patients')
        .doc('p1')
        .set({
      'fullName': patientName,
      'age': patientAge,
      'diagnosis': diagnosis,
      'caregiverId': testUid,
      'healthCenterName': 'Hospital General',
      'healthCenterAddress': 'Calle Falsa 123',
      'healthCenterPhone': '0991234567',
      'emergencyContactPhone': '0997654321',
      'createdAt': DateTime(2024, 2, 1),
    });
  }

  group('ProfileScreen — C.5: Data from providers', () {
    testWidgets('shows caregiver name from userProvider', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupData();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildProfile(container));
      await tester.pumpAndSettle();

      expect(find.text('María García'), findsOneWidget);
    });

    testWidgets('shows patient name from currentPatientProvider',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupData();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildProfile(container));
      await tester.pumpAndSettle();

      expect(find.text('Lucas García'), findsOneWidget);
    });
  });

  group('ProfileScreen — C.5: Edit caregiver dialog', () {
    testWidgets('tapping caregiver edit opens dialog with pre-filled fields',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupData();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildProfile(container));
      await tester.pumpAndSettle();

      // Tap the edit icon on the avatar (Icons.edit inside the avatar section)
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();

      // Dialog should appear with title
      expect(find.text('Editar cuidador'), findsOneWidget);

      // Fields should be pre-populated
      expect(find.widgetWithText(TextField, 'María García'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Madre'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1234567890'), findsOneWidget);
    });

    testWidgets('saving caregiver dialog updates Firestore', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupData();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildProfile(container));
      await tester.pumpAndSettle();

      // Open caregiver edit dialog via avatar edit icon
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();

      // Clear and type new name
      final nameField = find.widgetWithText(TextField, 'María García');
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Ana López');
      await tester.pump();

      // Tap save
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Verify Firestore was updated
      final userDoc = await fakeFirestore.collection('users').doc(testUid).get();
      expect(userDoc.data()!['displayName'], 'Ana López');
    });
  });

  group('ProfileScreen — C.5: Edit patient dialog', () {
    testWidgets('tapping patient edit opens dialog with pre-filled fields',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupData();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildProfile(container));
      await tester.pumpAndSettle();

      // Tap the "Editar" button in the patient card (only one text "Editar" now)
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Editar paciente'), findsOneWidget);

      // Fields should be pre-populated
      expect(find.widgetWithText(TextField, 'Lucas García'), findsOneWidget);
    });

    testWidgets('saving patient dialog updates Firestore', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupData();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildProfile(container));
      await tester.pumpAndSettle();

      // Open patient edit dialog
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      // Clear and type new name
      final nameField = find.widgetWithText(TextField, 'Lucas García');
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Lucas López');
      await tester.pump();

      // Tap save
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Verify Firestore was updated
      final patientDoc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc('p1')
          .get();
      expect(patientDoc.data()!['fullName'], 'Lucas López');
    });
  });
}
