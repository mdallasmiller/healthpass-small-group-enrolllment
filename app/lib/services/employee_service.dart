import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import '../utils/codes.dart';
import 'db.dart';

/// Firestore CRUD for a group's employee roster (groups/{groupId}/employees).
class EmployeeService {
  FirebaseFirestore get _db => appDb;

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('employees');

  Stream<List<Employee>> watch(String groupId) => _col(groupId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Employee.fromDoc).toList());

  /// Adds an employee and returns the new document id.
  Future<String> add(String groupId, Employee e) async {
    final ref = await _col(groupId).add(e.toMap());
    return ref.id;
  }

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

  /// Returns the employee's invite code, generating and saving one if missing.
  Future<String> ensureAccessCode(String groupId, Employee e) async {
    if (e.accessCode.isNotEmpty) return e.accessCode;
    final code = generateAccessCode();
    await _col(groupId).doc(e.id!).update({'accessCode': code});
    return code;
  }

  /// One-shot read of all employees in a group (used for import de-duplication).
  Future<List<Employee>> getAll(String groupId) async {
    final snap = await _col(groupId).get();
    return snap.docs.map(Employee.fromDoc).toList();
  }

  /// Reads a single employee (used by the enrollment portal to validate).
  Future<Employee?> getEmployee(String groupId, String employeeId) async {
    final doc = await _col(groupId).doc(employeeId).get();
    return doc.exists ? Employee.fromDoc(doc) : null;
  }
}
