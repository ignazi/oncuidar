import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/daily_record/daily_record_screen.dart';

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

  Widget buildDailyRecord(ProviderContainer container, {String? recordId}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/record',
          routes: [
            GoRoute(
              path: '/record',
              builder: (_, _) => DailyRecordScreen(recordId: recordId),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (_, _) =>
                  const Scaffold(body: Text('dashboard')),
            ),
          ],
        ),
      ),
    );
  }

  group('DailyRecordScreen', () {
    testWidgets('shows record type buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildDailyRecord(container));
      await tester.pump();

      expect(find.textContaining('Registro programado'), findsOneWidget);
      expect(find.text('Registro extra'), findsOneWidget);
    });

    testWidgets('saves new record to Firestore', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildDailyRecord(container));
      await tester.pump();
      await tester.pumpAndSettle();

      // Enter temperature
      final tempField = find.widgetWithText(TextField, '37.0');
      await tester.enterText(tempField, '38.5');
      await tester.pump();

      // Tap save
      final saveButton = find.text('Guardar registro');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify record was saved to Firestore
      final records = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc('p1')
          .collection('dailyRecords')
          .get();
      expect(records.docs, hasLength(1));
      expect(records.docs.first.data()['recordType'], isNotNull);
    });

    testWidgets('loads existing record when recordId provided',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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
          .doc('p1')
          .collection('dailyRecords')
          .doc('existing-record')
          .set({
        'date': DateTime(2024, 7, 1),
        'createdAt': DateTime(2024, 7, 1, 10, 0),
        'recordType': 'extra',
        'vitalSigns': {
          'temperature': 38.5,
          'heartRate': 90,
          'oxygenSaturation': 96,
          'respiratoryRate': 20,
        },
        'symptoms': [
          {'name': 'Fiebre', 'intensity': 7}
        ],
        'generalNotes': 'Nota de prueba',
        'alertLevel': 'alerta',
      });

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
          buildDailyRecord(container, recordId: 'existing-record'));

      // Let stream providers settle
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify form is populated with vitals from the record
      expect(find.text('38.5'), findsWidgets);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('shows dynamic record count (1/max)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildDailyRecord(container));
      await tester.pump();

      // Should show "Registro programado 1/3" (default maxRecordsPerDay is 3)
      expect(find.textContaining('Registro programado 1/'), findsOneWidget);
    });
  });
}
