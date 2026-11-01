import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'nutrition_goals.dart';
import 'nutrition_entry.dart';

class NutritionService {
  NutritionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Zaloguj się, aby korzystać z dziennika.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection('users').doc(_uid).collection('nutritionEntries');

  DocumentReference<Map<String, dynamic>> get _goals => _firestore
      .collection('users')
      .doc(_uid)
      .collection('settings')
      .doc('nutritionGoals');

  Stream<List<NutritionEntry>> watchDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return _entries
        .where('consumedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('consumedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('consumedAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(NutritionEntry.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<String> addEntry(NutritionEntry entry) async {
    entry.validate();

    final doc = _entries.doc();
    await doc.set({
      ...entry.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateEntry(NutritionEntry entry) async {
    entry.validate();

    if (entry.id.trim().isEmpty) {
      throw ArgumentError('Brak identyfikatora posiłku.');
    }

    await _entries.doc(entry.id).update({
      ...entry.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEntry(String entryId) async {
    if (entryId.trim().isEmpty) {
      throw ArgumentError('Brak identyfikatora posiłku.');
    }

    await _entries.doc(entryId).delete();
  }

  Future<NutritionGoals> getGoals() async {
    final snapshot = await _goals.get();
    return NutritionGoals.fromFirestore(snapshot.data());
  }

  Stream<NutritionGoals> watchGoals() {
    return _goals.snapshots().map(
      (snapshot) => NutritionGoals.fromFirestore(snapshot.data()),
    );
  }

  Future<void> saveGoals(NutritionGoals goals) async {
    goals.validate();

    await _goals.set({
      ...goals.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
