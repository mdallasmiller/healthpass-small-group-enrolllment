import 'package:cloud_firestore/cloud_firestore.dart';

/// Saves a completed enrollment for an employee.
///
/// Dev note: the portal writes directly (anonymous auth). SSN is stored as
/// entered for now; production moves the write behind a Cloud Function and
/// encrypts sensitive fields (M9).
class EnrollmentService {
  Future<void> submit(
    String groupId,
    String employeeId,
    Map<String, dynamic> data,
  ) async {
    final db = FirebaseFirestore.instance;
    final emp =
        db.collection('groups').doc(groupId).collection('employees').doc(employeeId);
    await emp.collection('enrollment').doc('data').set({
      ...data,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    await emp.update({'status': 'completed'});
  }

  /// All submitted enrollments for a group, each as
  /// {employeeId, employee: {...}, data: {...}}. Used for census + reports.
  Future<List<Map<String, dynamic>>> getGroupEnrollments(String groupId) async {
    final db = FirebaseFirestore.instance;
    final emps =
        await db.collection('groups').doc(groupId).collection('employees').get();
    final out = <Map<String, dynamic>>[];
    for (final e in emps.docs) {
      final enr = await e.reference.collection('enrollment').doc('data').get();
      if (enr.exists && enr.data() != null) {
        out.add({'employeeId': e.id, 'employee': e.data(), 'data': enr.data()!});
      }
    }
    return out;
  }

  /// Reads a submitted enrollment for the admin view (null if not submitted).
  Future<Map<String, dynamic>?> getEnrollment(
    String groupId,
    String employeeId,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('employees')
        .doc(employeeId)
        .collection('enrollment')
        .doc('data')
        .get();
    return doc.exists ? doc.data() : null;
  }
}
