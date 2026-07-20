import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/history/history_screen.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService testService;
  const testUid = 'test-uid-123';
  const testPid = 'p1';

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

  Widget buildHistory(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/history',
          routes: [
            GoRoute(
              path: '/history',
              builder: (_, _) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/record/edit/:id',
              builder: (_, state) => Scaffold(
                body: Text('edit:${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> setupPatient() async {
    await fakeFirestore
        .collection('users')
        .doc(testUid)
        .collection('patients')
        .doc(testPid)
        .set({
      'fullName': 'Lucas García',
      'diagnosis': 'Leucemia',
      'caregiverId': testUid,
      'createdAt': DateTime(2024, 2, 1),
    });
  }

  Future<void> addRecord({
    required String id,
    required double temp,
    required int heartRate,
    required int oxygen,
    required int respRate,
    required String alertLevel,
    String? notes,
  }) async {
    await fakeFirestore
        .collection('users')
        .doc(testUid)
        .collection('patients')
        .doc(testPid)
        .collection('dailyRecords')
        .doc(id)
        .set({
      'date': DateTime(2026, 4, 24),
      'createdAt': DateTime(2026, 4, 24, 10, 25),
      'recordType': 'programado',
      'vitalSigns': {
        'temperature': temp,
        'heartRate': heartRate,
        'oxygenSaturation': oxygen,
        'respiratoryRate': respRate,
      },
      'symptoms': [],
      'generalNotes': notes,
      'alertLevel': alertLevel,
    });
  }

  group('HistoryScreen — C.1: StreamProvider integration', () {
    testWidgets('shows real records from dailyRecordsProvider', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addRecord(
        id: 'r1',
        temp: 37.5,
        heartRate: 85,
        oxygen: 97,
        respRate: 18,
        alertLevel: 'normal',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      // Should show real vitals from the record, NOT mock data
      expect(find.text('37.5°C'), findsOneWidget);
      expect(find.text('85 lpm'), findsOneWidget);
      expect(find.text('97%'), findsOneWidget);
      expect(find.text('18 rpm'), findsOneWidget);
    });

    testWidgets('shows multiple records from stream', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addRecord(
        id: 'r1',
        temp: 37.5,
        heartRate: 85,
        oxygen: 97,
        respRate: 18,
        alertLevel: 'normal',
      );
      await addRecord(
        id: 'r2',
        temp: 38.2,
        heartRate: 100,
        oxygen: 95,
        respRate: 22,
        alertLevel: 'alerta',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      // Both records should appear
      expect(find.text('37.5°C'), findsOneWidget);
      expect(find.text('38.2°C'), findsOneWidget);
    });
  });

  group('HistoryScreen — C.2: Empty state', () {
    testWidgets('shows empty state when no records exist', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      expect(find.text('No hay registros aún'), findsOneWidget);
    });

    testWidgets('does not show empty state when records exist', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addRecord(
        id: 'r1',
        temp: 37.5,
        heartRate: 85,
        oxygen: 97,
        respRate: 18,
        alertLevel: 'normal',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      expect(find.text('No hay registros aún'), findsNothing);
    });
  });

  group('HistoryScreen — C.3: Edit navigation', () {
    testWidgets('edit button navigates to /record/edit/:id', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addRecord(
        id: 'r1',
        temp: 37.5,
        heartRate: 85,
        oxygen: 97,
        respRate: 18,
        alertLevel: 'normal',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      // Swipe right on the Dismissible to trigger edit via confirmDismiss
      final dismissible = find.byType(Dismissible);
      expect(dismissible, findsOneWidget);
      await tester.drag(dismissible, const Offset(500, 0));
      await tester.pumpAndSettle();

      // Should navigate to /record/edit/r1
      expect(find.text('edit:r1'), findsOneWidget);
    });
  });

  group('HistoryScreen — C.4: Delete with confirmation', () {
    testWidgets('shows confirmation dialog on delete tap', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addRecord(
        id: 'r1',
        temp: 37.5,
        heartRate: 85,
        oxygen: 97,
        respRate: 18,
        alertLevel: 'normal',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      // Swipe left on the Dismissible to trigger delete dialog
      final dismissible = find.byType(Dismissible);
      expect(dismissible, findsOneWidget);
      await tester.drag(dismissible, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('¿Eliminar este registro?'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('cancel dismisses dialog without deleting', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addRecord(
        id: 'r1',
        temp: 37.5,
        heartRate: 85,
        oxygen: 97,
        respRate: 18,
        alertLevel: 'normal',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      // Swipe left to trigger delete dialog
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Dialog dismissed, record still visible
      expect(find.text('37.5°C'), findsWidgets);
    });

    testWidgets('confirm delete removes record from Firestore', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addRecord(
        id: 'r1',
        temp: 37.5,
        heartRate: 85,
        oxygen: 97,
        respRate: 18,
        alertLevel: 'normal',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHistory(container));
      await tester.pumpAndSettle();

      // Swipe left to trigger delete dialog
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Tap Eliminar
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      // Verify record was deleted from Firestore
      final records = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPid)
          .collection('dailyRecords')
          .get();
      expect(records.docs, isEmpty);
    });
  });
}
