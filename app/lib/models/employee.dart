import 'package:cloud_firestore/cloud_firestore.dart';

/// Enrollment status for a rostered employee.
enum EmployeeStatus { pending, opened, inProgress, completed }

extension EmployeeStatusLabel on EmployeeStatus {
  String get label => switch (this) {
        EmployeeStatus.pending => 'Pending',
        EmployeeStatus.opened => 'Opened',
        EmployeeStatus.inProgress => 'In progress',
        EmployeeStatus.completed => 'Completed',
      };
  String get key => name;
}

class Employee {
  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String accessCode; // invite code for the enrollment link (dev: plaintext)
  final EmployeeStatus status;
  final DateTime? createdAt;

  Employee({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
    this.accessCode = '',
    this.status = EmployeeStatus.pending,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'accessCode': accessCode,
        'status': status.name,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Employee(
      id: doc.id,
      firstName: (m['firstName'] ?? '') as String,
      lastName: (m['lastName'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      accessCode: (m['accessCode'] ?? '') as String,
      status: EmployeeStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => EmployeeStatus.pending,
      ),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Employee copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? accessCode,
    EmployeeStatus? status,
  }) =>
      Employee(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        accessCode: accessCode ?? this.accessCode,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
