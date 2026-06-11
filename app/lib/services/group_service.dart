import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';

/// Firestore CRUD for groups.
class GroupService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('groups');

  Stream<List<Group>> watchGroups() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Group.fromDoc).toList());

  Future<Group?> getGroup(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? Group.fromDoc(doc) : null;
  }

  Future<String> create(Group group) async {
    final data = group.toMap();
    data['createdBy'] = FirebaseAuth.instance.currentUser?.uid;
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(String id, Group group) async {
    final data = group.toMap()..remove('createdAt');
    await _col.doc(id).update(data);
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
