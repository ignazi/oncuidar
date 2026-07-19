import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/reminders/reminders_screen.dart';

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

  Widget buildReminders(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/reminders',
          routes: [
            GoRoute(
              path: '/reminders',
              builder: (_, _) => const RemindersScreen(),
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

  Future<void> addReminder({
    required String id,
    required String title,
    required String type,
    bool isActive = true,
    DateTime? dateTime,
  }) async {
    await fakeFirestore
        .collection('users')
        .doc(testUid)
        .collection('patients')
        .doc(testPid)
        .collection('reminders')
        .doc(id)
        .set({
      'title': title,
      'type': type,
      'isActive': isActive,
      'dateTime': (dateTime ?? DateTime(2026, 7, 15, 8, 0)).toIso8601String(),
      'repeatDays': ['lun', 'mar', 'mie', 'jue', 'vie'],
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('RemindersScreen — D.6: StreamProvider integration', () {
    testWidgets('shows real reminders from remindersProvider',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addReminder(id: 'rem1', title: 'Medicamento matutino', type: 'medicamento');
      await addReminder(id: 'rem2', title: 'Medición de la tarde', type: 'medicion');

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      expect(find.text('Medicamento matutino'), findsOneWidget);
      expect(find.text('Medición de la tarde'), findsOneWidget);
    });

    testWidgets('shows empty state when no reminders exist',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      expect(find.text('No tienes recordatorios.'), findsOneWidget);
    });
  });

  group('RemindersScreen — D.7: Create reminder', () {
    testWidgets('quick add button opens create form',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addReminder(id: 'rem1', title: 'Existing', type: 'medicamento');

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      await tester.tap(find.text('Nuevo +'));
      await settle(tester);

      expect(find.text('Nuevo recordatorio'), findsOneWidget);
    });

    testWidgets('create form saves reminder to Firestore',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addReminder(id: 'rem1', title: 'Existing', type: 'medicamento');

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      await tester.tap(find.text('Nuevo +'));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('reminder_title')), 'Control médico');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final reminders = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPid)
          .collection('reminders')
          .get();
      expect(reminders.docs.length, 2);
      expect(reminders.docs.any((d) => d.data()['title'] == 'Control médico'), isTrue);
    });
  });

  group('RemindersScreen — D.8: Toggle active', () {
    testWidgets('toggle updates isActive in Firestore',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addReminder(
        id: 'rem1',
        title: 'Medicamento',
        type: 'medicamento',
        isActive: true,
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      // Find toggle - it's the 44x24 container at the end of each reminder card
      final toggleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 44 &&
            widget.constraints?.maxHeight == 24,
      );

      expect(toggleFinder, findsWidgets);
      await tester.tap(toggleFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPid)
          .collection('reminders')
          .doc('rem1')
          .get();

      expect(doc.data()?['isActive'], false);
    });
  });

  group('RemindersScreen — D.9: Delete with confirmation', () {
    testWidgets('shows confirmation dialog on delete tap',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addReminder(id: 'rem1', title: 'Medicamento', type: 'medicamento');

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await settle(tester);

      expect(find.text('¿Eliminar este recordatorio?'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('cancel dismisses dialog without deleting',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addReminder(id: 'rem1', title: 'Medicamento', type: 'medicamento');

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await settle(tester);

      await tester.tap(find.text('Cancelar'));
      await settle(tester);

      final reminders = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPid)
          .collection('reminders')
          .get();
      expect(reminders.docs.length, 1);
    });

    testWidgets('confirm delete removes reminder from Firestore',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setupPatient();
      await addReminder(id: 'rem1', title: 'Medicamento', type: 'medicamento');

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildReminders(container));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await settle(tester);

      await tester.tap(find.text('Eliminar'));
      await settle(tester);

      final reminders = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(testPid)
          .collection('reminders')
          .get();
      expect(reminders.docs, isEmpty);
    });
  });
}
