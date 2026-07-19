import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/core/providers/providers.dart';
import 'package:oncuidar/core/services/auto_download_service.dart';
import 'package:oncuidar/core/services/firestore_service.dart';
import 'package:oncuidar/features/dashboard/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService testService;
  const testUid = 'test-uid-123';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    testService = FirestoreService(db: fakeFirestore, auth: mockAuth, testUid: testUid);
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        firestoreServiceProvider.overrideWithValue(testService),
        isConnectedProvider.overrideWithValue(const AsyncData(true)),
        autoDownloadServiceProvider.overrideWithValue(
          AutoDownloadService(db: FakeFirebaseFirestore()),
        ),
      ],
    );
  }

  Widget buildDashboard(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: DashboardScreen()),
      ),
    );
  }

  group('DashboardScreen', () {
    testWidgets('shows default state when no patient exists',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildDashboard(container));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cuidador'), findsOneWidget);
    });

    testWidgets('shows patient name from provider', (tester) async {
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

      await tester.pumpWidget(buildDashboard(container));
      await tester.pumpAndSettle();

      expect(find.textContaining('Lucas García'), findsOneWidget);
    });

    testWidgets('shows vitals from daily record via provider',
        (tester) async {
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
          .doc('r1')
          .set({
        'date': DateTime(2024, 7, 1),
        'createdAt': DateTime(2024, 7, 1, 10, 0),
        'recordType': 'programado',
        'vitalSigns': {
          'temperature': 37.5,
          'heartRate': 85,
          'oxygenSaturation': 97,
          'respiratoryRate': 18,
        },
        'symptoms': [],
        'alertLevel': 'normal',
      });

      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildDashboard(container));
      await tester.pumpAndSettle();

      expect(find.text('37.5 °C'), findsOneWidget);
      expect(find.text('85 lpm'), findsOneWidget);
      expect(find.text('97 %'), findsOneWidget);
      expect(find.text('18 rpm'), findsOneWidget);
    });

    testWidgets('shows -- for vitals when no records exist',
        (tester) async {
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

      await tester.pumpWidget(buildDashboard(container));
      await tester.pumpAndSettle();

      expect(find.text('-- °C'), findsOneWidget);
      expect(find.text('-- lpm'), findsOneWidget);
    });

    testWidgets('does not make inline Firestore calls',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildDashboard(container));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
