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

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth? _auth;
  final String? _testUid;

  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth, this._testUid})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid {
    if (_testUid != null) return _testUid;
    final user = _auth?.currentUser;
    if (user == null) throw StateError('No authenticated user');
    return user.uid;
  }

  DocumentReference get _userDoc => _db.collection('users').doc(_uid);

  // ── Users ──

  Stream<AppUser?> userStream() {
    return _userDoc.snapshots().map(
          (snap) => snap.exists
              ? AppUser.fromMap(snap.id, snap.data() as Map<String, dynamic>)
              : null,
        );
  }

  Future<void> updateUser(Map<String, dynamic> data) {
    return _userDoc.set(data, SetOptions(merge: true));
  }

  // ── Patients ──

  Stream<List<Patient>> patientsStream() {
    return _userDoc.collection('patients').snapshots().map(
          (snap) => snap.docs
              .map((d) => Patient.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<String> addPatient(Patient p) async {
    final ref = await _userDoc.collection('patients').add(p.toMap());
    return ref.id;
  }

  Future<void> updatePatient(String pid, Map<String, dynamic> data) {
    return _userDoc.collection('patients').doc(pid).set(data, SetOptions(merge: true));
  }

  // ── Daily Records ──

  /// Límite máximo de registros que se cargan por defecto.
  /// Un cuidador típico registra 1-2 entradas/día; 50 cubre ~1 mes.
  static const int _dailyRecordsLimit = 50;

  CollectionReference _dailyRecordsCol(String pid) =>
      _userDoc.collection('patients').doc(pid).collection('dailyRecords');

  /// Stream de los últimos [_dailyRecordsLimit] registros (para dashboard/recientes).
  Stream<List<DailyRecord>> dailyRecordsStream(String pid) {
    return _dailyRecordsCol(pid)
        .orderBy('createdAt', descending: true)
        .limit(_dailyRecordsLimit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DailyRecord.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
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
    return snap.docs
        .map((d) => DailyRecord.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDailyRecord(String pid, DailyRecord record) {
    return _dailyRecordsCol(pid)
        .doc(record.id)
        .set(record.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteDailyRecord(String pid, String recordId) {
    return _dailyRecordsCol(pid).doc(recordId).delete();
  }

  // ── Reminders ──

  CollectionReference _remindersCol(String pid) =>
      _userDoc.collection('patients').doc(pid).collection('reminders');

  Stream<List<Reminder>> remindersStream(String pid) {
    return _remindersCol(pid).snapshots().map(
          (snap) => snap.docs
              .map((d) => Reminder.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Future<String> addReminder(String pid, Reminder r) async {
    final ref = await _remindersCol(pid).add(r.toMap());
    return ref.id;
  }

  Future<void> updateReminder(String pid, String rid, Map<String, dynamic> data) {
    return _remindersCol(pid).doc(rid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteReminder(String pid, String rid) {
    return _remindersCol(pid).doc(rid).delete();
  }

  // ── User Checklists ──

  CollectionReference _userChecklistsCol(String pid) =>
      _userDoc.collection('patients').doc(pid).collection('userChecklists');

  Stream<List<UserChecklist>> userChecklistsStream(String pid) {
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
