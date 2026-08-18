import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_user.dart';
import '../../models/daily_record.dart';
import '../../models/educational_content.dart';
import '../../models/faq_item.dart';
import '../../models/orientation_rule.dart';
import '../../models/patient.dart';
import '../../models/reminder.dart';
import '../../models/user_checklist.dart';
import 'client_encryption_service.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth? _auth;
  final String? _testUid;
  final ClientEncryptionService _encryption;

  FirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    String? testUid,
    ClientEncryptionService? encryption,
  })  : _testUid = testUid,
        _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _encryption = encryption ??
            ClientEncryptionService(testKey: testUid != null
                ? 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY='
                : null);

  String get _uid {
    if (_testUid != null) return _testUid;
    final user = _auth?.currentUser;
    if (user == null) throw StateError('No authenticated user');
    return user.uid;
  }

  /// Returns true when there is an authenticated user (or test uid).
  /// Use this in stream methods to emit empty results instead of throwing.
  bool get _isAuthenticated => _testUid != null || _auth?.currentUser != null;

  DocumentReference get _userDoc => _db.collection('users').doc(_uid);

  // ── Users ──

  Stream<AppUser?> userStream() {
    if (!_isAuthenticated) return Stream.value(null);
    return _userDoc.snapshots().map(
          (snap) => snap.exists
              ? AppUser.fromMap(snap.id, snap.data() as Map<String, dynamic>)
              : null,
        );
  }

  Future<void> updateUser(Map<String, dynamic> data) {
    return _userDoc.set(data, SetOptions(merge: true));
  }

  Future<bool> isEncryptionPasswordConfigured() async {
    final user = await _userDoc.get();
    return (user.data() as Map<String, dynamic>?)?['encryption_version'] == 2;
  }

  Future<void> markEncryptionPasswordConfigured() {
    return _userDoc.set({
      'encryption_version': 2,
      'encryptionConfiguredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Comprueba la contraseña contra el primer dato cifrado disponible.
  Future<void> verifyEncryptionPassword() async {
    final patients = await _userDoc.collection('patients').get();
    for (final patient in patients.docs) {
      final data = patient.data();
      final name = data['nombre_cifrado'] as String?;
      final diagnosis = data['diagnostico_cifrado'] as String?;
      if (name != null) {
        await _encryption.decrypt(_uid, name);
        return;
      }
      if (diagnosis != null) {
        await _encryption.decrypt(_uid, diagnosis);
        return;
      }
      final records =
          await patient.reference.collection('dailyRecords').limit(1).get();
      for (final record in records.docs) {
        final notes =
            record.data()['contenido_del_registro_cifrado'] as String?;
        if (notes != null) {
          await _encryption.decrypt(_uid, notes);
          return;
        }
      }
    }
  }

  // ── Patients ──

  Stream<List<Patient>> patientsStream() {
    if (!_isAuthenticated) return Stream.value([]);
    return _userDoc.collection('patients').snapshots().asyncMap(
          (snap) => Future.wait(
            snap.docs.map((d) => _patientFromFirestore(d.id, d.data())),
          ),
        );
  }

  Future<String> addPatient(Patient p) async {
    final ref = _userDoc.collection('patients').doc();
    await ref.set(
      await _encryptPatientData(p.toMap()),
      SetOptions(merge: true),
    );
    return ref.id;
  }

  Future<void> updatePatient(String pid, Map<String, dynamic> data) async {
    await _userDoc
        .collection('patients')
        .doc(pid)
        .set(await _encryptPatientData(data), SetOptions(merge: true));
  }

  Future<void> deletePatient(String pid) {
    return _userDoc.collection('patients').doc(pid).delete();
  }

  // ── Daily Records ──

  /// Límite máximo de registros que se cargan por defecto.
  /// Un cuidador típico registra 1-2 entradas/día; 50 cubre ~1 mes.
  static const int _dailyRecordsLimit = 50;

  CollectionReference _dailyRecordsCol(String pid) =>
      _userDoc.collection('patients').doc(pid).collection('dailyRecords');

  /// Stream de los últimos [_dailyRecordsLimit] registros (para dashboard/recientes).
  Stream<List<DailyRecord>> dailyRecordsStream(String pid) {
    if (!_isAuthenticated) return Stream.value([]);
    return _dailyRecordsCol(pid)
        .orderBy('createdAt', descending: true)
        .limit(_dailyRecordsLimit)
        .snapshots()
        .asyncMap(
          (snap) => Future.wait(
            snap.docs.map(
              (d) => _dailyRecordFromFirestore(
                d.id,
                d.data() as Map<String, dynamic>,
              ),
            ),
          ),
        );
  }

  /// Carga la siguiente página de registros para paginación (history screen).
  /// [lastRecordDate] es la fecha del último registro cargado.
  Future<List<DailyRecord>> loadMoreDailyRecords(
      String pid, DateTime lastRecordDate) async {
    final snap = await _dailyRecordsCol(pid)
        .orderBy('createdAt', descending: true)
        .startAfter([lastRecordDate])
        .limit(_dailyRecordsLimit)
        .get();
    return Future.wait(
      snap.docs.map(
        (d) => _dailyRecordFromFirestore(
          d.id,
          d.data() as Map<String, dynamic>,
        ),
      ),
    );
  }

  Future<void> saveDailyRecord(String pid, DailyRecord record) async {
    if (record.patientId != pid) {
      throw ArgumentError.value(record.patientId, 'record.patientId',
          'Debe coincidir con el paciente de la ruta');
    }
    await _dailyRecordsCol(pid)
        .doc(record.id)
        .set(await _encryptDailyRecordData(record), SetOptions(merge: true));
  }

  Future<void> deleteDailyRecord(String pid, String recordId) {
    return _dailyRecordsCol(pid).doc(recordId).delete();
  }

  // ── Cifrado y migración de datos sensibles ──

  Future<Map<String, dynamic>> _encryptPatientData(
    Map<String, dynamic> source,
  ) async {
    final data = Map<String, dynamic>.from(source);
    await _replaceWithCiphertext(
      data,
      plaintextField: 'fullName',
      ciphertextField: 'nombre_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'diagnosis',
      ciphertextField: 'diagnostico_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'healthCenterName',
      ciphertextField: 'centro_salud_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'healthCenterAddress',
      ciphertextField: 'direccion_centro_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'healthCenterPhone',
      ciphertextField: 'telefono_centro_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'emergencyContactName',
      ciphertextField: 'contacto_emergencia_nombre_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'emergencyContactPhone',
      ciphertextField: 'contacto_emergencia_telefono_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'treatmentPhase',
      ciphertextField: 'fase_tratamiento_cifrado',
    );
    if (data.containsKey('nombre_cifrado') ||
        data.containsKey('diagnostico_cifrado')) {
      data['encryption_version'] = 2;
    }
    return data;
  }

  Future<Map<String, dynamic>> _encryptDailyRecordData(DailyRecord record) async {
    final data = record.toMap();
    await _replaceWithCiphertext(
      data,
      plaintextField: 'generalNotes',
      ciphertextField: 'contenido_del_registro_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'alertMessage',
      ciphertextField: 'mensaje_alerta_cifrado',
    );
    if (data.containsKey('symptoms')) {
      final symptoms = List<Map<String, dynamic>>.from(
        (data['symptoms'] as List).map((s) => Map<String, dynamic>.from(s as Map)),
      );
      await _encryptSymptomsNotes(symptoms);
      data['symptoms'] = symptoms;
    }
    data['encryption_version'] = 2;
    return data;
  }

  Future<void> _encryptSymptomsNotes(List<Map<String, dynamic>> symptoms) async {
    for (final s in symptoms) {
      final notes = s['notes'] as String?;
      if (notes != null && notes.isNotEmpty) {
        s['notes_cifrado'] = await _encryption.encrypt(_uid, notes);
      }
      s.remove('notes');
    }
  }

  Future<void> _replaceWithCiphertext(
    Map<String, dynamic> data, {
    required String plaintextField,
    required String ciphertextField,
  }) async {
    if (!data.containsKey(plaintextField)) return;
    final plaintext = data[plaintextField] as String?;
    data[plaintextField] = FieldValue.delete();
    data[ciphertextField] = plaintext == null || plaintext.isEmpty
        ? FieldValue.delete()
        : await _encryption.encrypt(_uid, plaintext);
  }

  Future<Patient> _patientFromFirestore(
    String id,
    Map<String, dynamic> source,
  ) async {
    final data = Map<String, dynamic>.from(source);
    data['fullName'] = await _decryptOrLegacy(data, 'nombre_cifrado', 'fullName');
    data['diagnosis'] = await _decryptOrLegacy(data, 'diagnostico_cifrado', 'diagnosis');
    data['healthCenterName'] = await _decryptOrLegacy(data, 'centro_salud_cifrado', 'healthCenterName');
    data['healthCenterAddress'] = await _decryptOrLegacy(data, 'direccion_centro_cifrado', 'healthCenterAddress');
    data['healthCenterPhone'] = await _decryptOrLegacy(data, 'telefono_centro_cifrado', 'healthCenterPhone');
    data['emergencyContactName'] = await _decryptOrLegacy(data, 'contacto_emergencia_nombre_cifrado', 'emergencyContactName');
    data['emergencyContactPhone'] = await _decryptOrLegacy(data, 'contacto_emergencia_telefono_cifrado', 'emergencyContactPhone');
    data['treatmentPhase'] = await _decryptOrLegacy(data, 'fase_tratamiento_cifrado', 'treatmentPhase');
    return Patient.fromMap(id, data);
  }

  Future<DailyRecord> _dailyRecordFromFirestore(
    String id,
    Map<String, dynamic> source,
  ) async {
    final data = Map<String, dynamic>.from(source);
    data['generalNotes'] = await _decryptOrLegacy(
      data,
      'contenido_del_registro_cifrado',
      'generalNotes',
    );
    data['alertMessage'] = await _decryptOrLegacy(
      data,
      'mensaje_alerta_cifrado',
      'alertMessage',
    );
    if (data.containsKey('symptoms')) {
      final symptoms = List<Map<String, dynamic>>.from(
        (data['symptoms'] as List).map((s) => Map<String, dynamic>.from(s as Map)),
      );
      await _decryptSymptomsNotes(symptoms);
      data['symptoms'] = symptoms;
    }
    return DailyRecord.fromMap(id, data);
  }

  Future<String?> _decryptOrLegacy(
    Map<String, dynamic> data,
    String ciphertextField,
    String legacyField,
  ) async {
    final ciphertext = data[ciphertextField] as String?;
    if (ciphertext != null && ciphertext.isNotEmpty) {
      return _encryption.decrypt(_uid, ciphertext);
    }
    return data[legacyField] as String?;
  }

  Future<void> _decryptSymptomsNotes(List<Map<String, dynamic>> symptoms) async {
    for (final s in symptoms) {
      final encrypted = s['notes_cifrado'] as String?;
      if (encrypted != null && encrypted.isNotEmpty) {
        s['notes'] = await _encryption.decrypt(_uid, encrypted);
      }
      s.remove('notes_cifrado');
    }
  }

  Future<void> _encryptReminderFields(Map<String, dynamic> data) async {
    await _replaceWithCiphertext(
      data,
      plaintextField: 'title',
      ciphertextField: 'titulo_cifrado',
    );
    await _replaceWithCiphertext(
      data,
      plaintextField: 'description',
      ciphertextField: 'descripcion_cifrado',
    );
  }

  Future<void> _decryptReminderFields(Map<String, dynamic> data) async {
    data['title'] = await _decryptOrLegacy(data, 'titulo_cifrado', 'title');
    data['description'] = await _decryptOrLegacy(data, 'descripcion_cifrado', 'description');
  }

  /// Convierte datos existentes a AES-GCM. Es seguro ejecutarlo más de una vez.
  Future<void> migrateLegacySensitiveData() async {
    final patients = await _userDoc.collection('patients').get();
    for (final patient in patients.docs) {
      final legacyPatient = patient.data();
      // Re-cifrar si quedan campos plaintext (nuevos campos incluidos)
      if (legacyPatient.containsKey('fullName') ||
          legacyPatient.containsKey('diagnosis') ||
          legacyPatient.containsKey('healthCenterName') ||
          legacyPatient.containsKey('healthCenterAddress') ||
          legacyPatient.containsKey('healthCenterPhone') ||
          legacyPatient.containsKey('emergencyContactName') ||
          legacyPatient.containsKey('emergencyContactPhone') ||
          legacyPatient.containsKey('treatmentPhase')) {
        await patient.reference.set(
          await _encryptPatientData(legacyPatient),
          SetOptions(merge: true),
        );
      }
      final records = await patient.reference.collection('dailyRecords').get();
      for (final record in records.docs) {
        final legacyRecord = record.data();
        final data = Map<String, dynamic>.from(legacyRecord)
          ..['paciente_id'] = patient.id;
        var needsSave = false;
        if (data.containsKey('generalNotes')) {
          await _replaceWithCiphertext(
            data,
            plaintextField: 'generalNotes',
            ciphertextField: 'contenido_del_registro_cifrado',
          );
          needsSave = true;
        }
        if (data.containsKey('alertMessage')) {
          await _replaceWithCiphertext(
            data,
            plaintextField: 'alertMessage',
            ciphertextField: 'mensaje_alerta_cifrado',
          );
          needsSave = true;
        }
        if (data.containsKey('symptoms')) {
          final symptoms = List<Map<String, dynamic>>.from(
            (data['symptoms'] as List).map((s) => Map<String, dynamic>.from(s as Map)),
          );
          final hasPlaintextNotes = symptoms.any(
            (s) => s.containsKey('notes') && (s['notes'] as String?)?.isNotEmpty == true,
          );
          if (hasPlaintextNotes) {
            await _encryptSymptomsNotes(symptoms);
            data['symptoms'] = symptoms;
            needsSave = true;
          }
        }
        if (needsSave) {
          data['encryption_version'] = 2;
          await record.reference.set(data, SetOptions(merge: true));
        }
      }
      // Migrar recordatorios del paciente
      final reminders = await patient.reference.collection('reminders').get();
      for (final reminder in reminders.docs) {
        final remData = reminder.data();
        if (remData.containsKey('title') || remData.containsKey('description')) {
          final data = Map<String, dynamic>.from(remData);
          await _encryptReminderFields(data);
          await reminder.reference.set(data, SetOptions(merge: true));
        }
      }
    }
  }

  // ── Reminders ──

  CollectionReference _remindersCol(String pid) =>
      _userDoc.collection('patients').doc(pid).collection('reminders');

  Stream<List<Reminder>> remindersStream(String pid) {
    if (!_isAuthenticated) return Stream.value([]);
    return _remindersCol(pid).snapshots().asyncMap(
          (snap) async {
            final results = <Reminder>[];
            for (final d in snap.docs) {
              try {
                final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
                await _decryptReminderFields(data);
                results.add(Reminder.fromMap(d.id, data));
              } catch (_) {
                // Skip docs that fail to decrypt — prevents entire batch failure
              }
            }
            return results;
          },
        );
  }

  Future<String> addReminder(String pid, Reminder r) async {
    final ref = _remindersCol(pid).doc();
    final data = r.toMap();
    await _encryptReminderFields(data);
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateReminder(String pid, String rid, Map<String, dynamic> data) async {
    await _encryptReminderFields(data);
    return _remindersCol(pid).doc(rid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteReminder(String pid, String rid) {
    return _remindersCol(pid).doc(rid).delete();
  }

  // ── User Checklists ──

  CollectionReference _userChecklistsCol(String pid) =>
      _userDoc.collection('patients').doc(pid).collection('userChecklists');

  Stream<List<UserChecklist>> userChecklistsStream(String pid) {
    if (!_isAuthenticated) return Stream.value([]);
    return _userChecklistsCol(pid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) =>
                  UserChecklist.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Future<String> addUserChecklist(String pid, UserChecklist c) async {
    final ref = await _userChecklistsCol(pid).add(c.toMap());
    return ref.id;
  }

  Future<void> updateUserChecklist(
      String pid, String cid, Map<String, dynamic> data) {
    return _userChecklistsCol(pid).doc(cid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteUserChecklist(String pid, String cid) {
    return _userChecklistsCol(pid).doc(cid).delete();
  }

  // ── Shared Content (read-only) ──

  Stream<List<OrientationRule>> orientationRulesStream() {
    return _db.collection('orientationRules').snapshots().map(
          (snap) => snap.docs
              .map((d) => OrientationRule.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<EducationalContent>> educationalContentStream() {
    return _db.collection('educationalContent').snapshots().map(
          (snap) => snap.docs
              .map((d) =>
                  EducationalContent.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<FaqItem>> faqsStream() {
    return _db.collection('faqs').snapshots().map(
          (snap) => snap.docs
              .map((d) => FaqItem.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<EducationalContent?> getArticle(String id) async {
    final doc = await _db.collection('educationalContent').doc(id).get();
    if (!doc.exists) return null;
    return EducationalContent.fromMap(doc.id, doc.data()!);
  }

  // ── Favorites ──

  Future<void> toggleArticleFavorite(String articleId, [String? legacyArticleId]) async {
    articleId = legacyArticleId ?? articleId;
    final doc = await _userDoc.get();
    final data = doc.data() as Map<String, dynamic>?;
    final favorites = List<String>.from(data?['favoriteArticles'] ?? []);
    if (favorites.contains(articleId)) {
      favorites.remove(articleId);
    } else {
      favorites.add(articleId);
    }
    await _userDoc.set({'favoriteArticles': favorites}, SetOptions(merge: true));
  }

  Stream<List<String>> favoriteArticlesStream() {
    if (!_isAuthenticated) return Stream.value([]);
    return _userDoc
        .snapshots()
        .map((snap) {
          final data = snap.data() as Map<String, dynamic>?;
          return List<String>.from(data?['favoriteArticles'] ?? []);
        });
  }

  // ── Chats (conversaciones de orientación) ──

  CollectionReference get _chatsCol => _userDoc.collection('chats');

  /// Stream de los últimos 20 chats, ordenados por última actividad.
  Stream<List<Map<String, dynamic>>> chatsStream() {
    if (!_isAuthenticated) return Stream.value([]);
    return _chatsCol
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }

  /// Crea un chat nuevo con mensaje de bienvenida.
  Future<String> createChat(String title, List<Map<String, dynamic>> messages) async {
    final ref = await _chatsCol.add({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'messages': messages,
    });
    return ref.id;
  }

  /// Actualiza los mensajes y timestamp de un chat.
  Future<void> updateChat(
      String chatId, List<Map<String, dynamic>> messages,
      {String? title}) async {
    final data = <String, dynamic>{
      'messages': messages,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (title != null) data['title'] = title;
    return _chatsCol.doc(chatId).set(data, SetOptions(merge: true));
  }

  /// Elimina un chat permanentemente.
  Future<void> deleteChat(String chatId) async {
    return _chatsCol.doc(chatId).delete();
  }

  /// Obtiene un chat por ID.
  Future<Map<String, dynamic>?> getChat(String chatId) async {
    final doc = await _chatsCol.doc(chatId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    return {'id': doc.id, ...data};
  }

  /// Renombra un chat.
  Future<void> renameChat(String chatId, String newTitle) async {
    return _chatsCol.doc(chatId).update({'title': newTitle});
  }
}
