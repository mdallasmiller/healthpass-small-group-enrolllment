import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';

/// Firestore CRUD for a group's employee roster (groups/{groupId}/employees).
class EmployeeService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('employees');

  Stream<List<Employee>> watch(String groupId) => _col(groupId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Employee.fromDoc).toList());

  Future<void> add(String groupId, Employee e) => _col(groupId).add(e.toMap());

  /// Bulk add (e.g. CSV import) in a single batched write.
  Future<int> addMany(String groupId, List<Employee> employees) async {
    if (employees.isEmpty) return 0;
    final batch = _db.batch();
    final col = _col(groupId);
    for (final e in employees) {
      batch.set(col.doc(), e.toMap());
    }
    await batch.commit();
    return employees.length;
  }

  Future<void> update(String groupId, String id, Employee e) =>
      _col(groupId).doc(id).update(e.toMap()..remove('createdAt'));

  Future<void> delete(String groupId, String id) =>
      _col(groupId).doc(id).delete();
}
