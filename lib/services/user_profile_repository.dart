import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileRepository {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('users');

  Future<void> setProfile({
    required String uid,
    required String name,
    required String email,
    required int age,
    required double height,
    required double weight,
  }) async {
    await _col.doc(uid).set({
      'name': name,
      'email': email,
      'age': age,
      'height': height,
      'weight': weight,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? email,
    int? age,
    double? height,
    double? weight,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (age != null) 'age': age,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (data.length == 1) return; // only updatedAt
    await _col.doc(uid).update(data);
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _col.doc(uid).get();
    return doc.data();
  }
}

