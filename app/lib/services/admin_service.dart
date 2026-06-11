import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Determines whether the signed-in user is an authorized admin, and can
/// claim the first-admin slot on a fresh project.
class AdminService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  Future<bool> isAdmin(String uid) async {
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

  /// Claims the first admin slot. The Cloud Function only grants this when no
  /// admins exist yet, so it is safe to call after sign-up/sign-in.
  Future<bool> bootstrapFirstAdmin() async {
    final callable = _functions.httpsCallable('bootstrapFirstAdmin');
    final res = await callable.call();
    final data = res.data as Map?;
    return (data?['granted'] ?? false) as bool;
  }
}
