import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/models/alert_level.dart';
import 'package:oncuidar/models/app_user.dart';
import 'package:oncuidar/models/daily_record.dart';
import 'package:oncuidar/core/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService service;
  const testUid = 'test-uid-123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    service = FirestoreService(db: fakeFirestore, auth: mockAuth, testUid: testUid);
  });

  group('userStream', () {
    test('emits AppUser from Firestore', () async {
      await fakeFirestore.collection('users').doc(testUid).set({
        'displayName': 'María García',
        'email': 'maria@test.com',
        'phone': '555-1234',
        'relationship': 'Madre',
        'createdAt': DateTime(2024, 1, 15),
      });

      final user = await service.userStream().first;

      expect(user, isA<AppUser>());
      expect(user!.uid, testUid);
      expect(user.displayName, 'María García');
      expect(user.email, 'maria@test.com');
    });

    test('emits updated user when document changes', () async {
      await fakeFirestore.collection('users').doc(testUid).set({
        'displayName': 'María García',
        'createdAt': DateTime(2024, 1, 15),
      });

      final first = await service.userStream().first;
      expect(first!.displayName, 'María García');

      await fakeFirestore.collection('users').doc(testUid).update({
        'displayName': 'María López',
      });

      final second = await service.userStream().first;
      expect(second!.displayName, 'María López');
    });
  });

  group('patientsStream', () {
    test('emits list of patients for current user', () async {
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
        'diagnosis': 'Tumor cerebral',
        'caregiverId': testUid,
        'createdAt': DateTime(2024, 3, 1),
      });

      final patients = await service.patientsStream().first;

      expect(patients, hasLength(2));
      expect(patients[0].fullName, 'Lucas García');
      expect(patients[1].fullName, 'Sofía López');
    });

    test('emits empty list when no patients exist', () async {
      final patients = await service.patientsStream().first;
      expect(patients, isEmpty);
    });
  });

  group('dailyRecordsStream', () {
    test('emits records ordered by createdAt descending', () async {
      final pid = 'patient-1';
      await _seedDailyRecord(fakeFirestore, testUid, pid, 'r1',
          createdAt: DateTime(2024, 6, 1), temp: 36.5);
      await _seedDailyRecord(fakeFirestore, testUid, pid, 'r2',
          createdAt: DateTime(2024, 6, 15), temp: 38.2);
      await _seedDailyRecord(fakeFirestore, testUid, pid, 'r3',
          createdAt: DateTime(2024, 6, 10), temp: 37.0);

      final records = await service.dailyRecordsStream(pid).first;

      expect(records, hasLength(3));
      expect(records[0].id, 'r2');
      expect(records[1].id, 'r3');
      expect(records[2].id, 'r1');
    });

    test('emits empty list when no records exist', () async {
      final records = await service.dailyRecordsStream('nonexistent').first;
      expect(records, isEmpty);
    });
  });

  group('saveDailyRecord', () {
    test('saves record to correct Firestore path', () async {
      final pid = 'patient-1';
      final record = DailyRecord(
        id: 'new-record',
        patientId: pid,
        date: DateTime(2024, 7, 1),
        createdAt: DateTime(2024, 7, 1, 10, 0),
        recordType: 'programado',
        symptoms: [],
        alertLevel: AlertLevel.normal,
      );

      await service.saveDailyRecord(pid, record);

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(pid)
          .collection('dailyRecords')
          .doc('new-record')
          .get();

      expect(doc.exists, true);
      expect(doc.data()?['recordType'], 'programado');
    });

    test('updates existing record with merge', () async {
      final pid = 'patient-1';
      await _seedDailyRecord(fakeFirestore, testUid, pid, 'existing',
          createdAt: DateTime(2024, 7, 1), temp: 36.5);

      final updated = DailyRecord(
        id: 'existing',
        patientId: pid,
        date: DateTime(2024, 7, 1),
        createdAt: DateTime(2024, 7, 1, 10, 0),
        recordType: 'extra',
        symptoms: [],
        alertLevel: AlertLevel.normal,
      );

      await service.saveDailyRecord(pid, updated);

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(pid)
          .collection('dailyRecords')
          .doc('existing')
          .get();

      expect(doc.data()?['recordType'], 'extra');
    });
  });

  group('deleteDailyRecord', () {
    test('removes record from Firestore', () async {
      final pid = 'patient-1';
      await _seedDailyRecord(fakeFirestore, testUid, pid, 'to-delete',
          createdAt: DateTime(2024, 7, 1), temp: 36.5);

      await service.deleteDailyRecord(pid, 'to-delete');

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(pid)
          .collection('dailyRecords')
          .doc('to-delete')
          .get();

      expect(doc.exists, false);
    });
  });

  group('remindersStream', () {
    test('emits reminders for patient', () async {
      final pid = 'patient-1';
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('patients')
          .doc(pid)
          .collection('reminders')
          .doc('rem1')
          .set({
        'type': 'medicamento',
        'title': 'Paracetamol',
        'description': 'Tomar cada 8 horas',
        'dateTime': DateTime(2024, 7, 1, 8, 0),
        'repeatDays': ['lun', 'mar', 'mie'],
        'isActive': true,
        'createdAt': DateTime(2024, 7, 1),
      });

      final reminders = await service.remindersStream(pid).first;

      expect(reminders, hasLength(1));
      expect(reminders[0].title, 'Paracetamol');
      expect(reminders[0].type, 'medicamento');
      expect(reminders[0].isActive, true);
    });
  });

  group('orientationRulesStream', () {
    test('emits orientation rules', () async {
      await fakeFirestore.collection('orientationRules').doc('rule1').set({
        'category': 'Fiebre',
        'subQuestion': '¿Qué hacer si tiene fiebre?',
        'answer': 'Dar paracetamol y vigilar.',
        'alertLevel': 'yellow',
        'tags': ['fiebre', 'temperatura'],
      });

      final rules = await service.orientationRulesStream().first;

      expect(rules, hasLength(1));
      expect(rules[0].subQuestion, '¿Qué hacer si tiene fiebre?');
      expect(rules[0].tags, contains('fiebre'));
    });
  });

  group('educationalContentStream', () {
    test('emits educational content', () async {
      await fakeFirestore.collection('educationalContent').doc('art1').set({
        'title': 'Cuidados durante quimioterapia',
        'category': 'Guías',
        'topic': 'Nutrición',
        'body': 'Contenido completo del artículo...',
        'imageUrl': 'https://example.com/img.jpg',
        'createdAt': DateTime(2024, 5, 1),
      });

      final content = await service.educationalContentStream().first;

      expect(content, hasLength(1));
      expect(content[0].title, 'Cuidados durante quimioterapia');
      expect(content[0].category, 'Guías');
    });
  });

  group('faqsStream', () {
    test('emits FAQ items', () async {
      await fakeFirestore.collection('faqs').doc('faq1').set({
        'question': '¿Qué es quimioterapia?',
        'answer': 'Es un tratamiento con medicamentos.',
        'category': 'Tratamiento',
      });

      final faqs = await service.faqsStream().first;

      expect(faqs, hasLength(1));
      expect(faqs[0].question, '¿Qué es quimioterapia?');
      expect(faqs[0].category, 'Tratamiento');
    });

    test('emits empty list when no faqs exist', () async {
      final faqs = await service.faqsStream().first;
      expect(faqs, isEmpty);
    });
  });

  group('getArticle', () {
    test('returns article by ID', () async {
      await fakeFirestore.collection('educationalContent').doc('art1').set({
        'title': 'Artículo de prueba',
        'category': 'Videos',
        'topic': 'Ejercicio',
        'body': 'Contenido del artículo.',
        'createdAt': DateTime(2024, 5, 1),
      });

      final article = await service.getArticle('art1');

      expect(article, isNotNull);
      expect(article!.title, 'Artículo de prueba');
      expect(article.body, 'Contenido del artículo.');
    });

    test('returns null for nonexistent article', () async {
      final article = await service.getArticle('nonexistent');
      expect(article, isNull);
    });
  });
}

Future<void> _seedDailyRecord(
  FakeFirebaseFirestore db,
  String uid,
  String pid,
  String rid, {
  required DateTime createdAt,
  required double temp,
}) async {
  await db
      .collection('users')
      .doc(uid)
      .collection('patients')
      .doc(pid)
      .collection('dailyRecords')
      .doc(rid)
      .set({
    'date': createdAt,
    'createdAt': createdAt,
    'recordType': 'programado',
    'vitalSigns': {'temperature': temp},
    'symptoms': [],
    'alertLevel': 'normal',
  });
}
