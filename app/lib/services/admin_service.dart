import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db.dart';

/// Determines whether the signed-in user is an authorized admin, and can
/// claim the first-admin slot.
class AdminService {
  FirebaseFirestore get _db => appDb;

  Future<bool> isAdmin(String uid) async {
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

  /// Provisions the current user as an admin.
  ///
  /// TEMP (dev): writes the admin record directly while Cloud Functions are not
  /// deployed (Spark plan). For production this should call the first-admin-only
  /// `bootstrapFirstAdmin` Cloud Function instead.
  Future<bool> bootstrapFirstAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await _db.collection('admins').doc(user.uid).set({
      'email': user.email,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
