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
  final String middleName;
  final String lastName;
  final String email;
  final String phone;
  final String accessCode; // invite code for the enrollment link (dev: plaintext)
  final EmployeeStatus status;
  final DateTime? createdAt;

  // Census-import demographics (auto-loaded into the enrollment portal).
  final String ssn;
  final String dob;
  final String gender;
  final String dateOfHire;
  final String tobacco; // 'Yes' / 'No' / ''
  final String mobilePhone;
  final String homePhone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String zip;
  final String jobTitle;
  final String benefitClass;
  final String employmentStatus; // Full-Time / Part-Time
  final bool eligible; // false when benefit class is ineligible -> no invite

  Employee({
    this.id,
    required this.firstName,
    required this.lastName,
    this.middleName = '',
    required this.email,
    this.phone = '',
    this.accessCode = '',
    this.status = EmployeeStatus.pending,
    this.createdAt,
    this.ssn = '',
    this.dob = '',
    this.gender = '',
    this.dateOfHire = '',
    this.tobacco = '',
    this.mobilePhone = '',
    this.homePhone = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.jobTitle = '',
    this.benefitClass = '',
    this.employmentStatus = '',
    this.eligible = true,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'accessCode': accessCode,
        'status': status.name,
        'ssn': ssn,
        'dob': dob,
        'gender': gender,
        'dateOfHire': dateOfHire,
        'tobacco': tobacco,
        'mobilePhone': mobilePhone,
        'homePhone': homePhone,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'city': city,
        'state': state,
        'zip': zip,
        'jobTitle': jobTitle,
        'benefitClass': benefitClass,
        'employmentStatus': employmentStatus,
        'eligible': eligible,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    String s(String k) => (m[k] ?? '') as String;
    return Employee(
      id: doc.id,
      firstName: s('firstName'),
      middleName: s('middleName'),
      lastName: s('lastName'),
      email: s('email'),
      phone: s('phone'),
      accessCode: s('accessCode'),
      status: EmployeeStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => EmployeeStatus.pending,
      ),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      ssn: s('ssn'),
      dob: s('dob'),
      gender: s('gender'),
      dateOfHire: s('dateOfHire'),
      tobacco: s('tobacco'),
      mobilePhone: s('mobilePhone'),
      homePhone: s('homePhone'),
      addressLine1: s('addressLine1'),
      addressLine2: s('addressLine2'),
      city: s('city'),
      state: s('state'),
      zip: s('zip'),
      jobTitle: s('jobTitle'),
      benefitClass: s('benefitClass'),
      employmentStatus: s('employmentStatus'),
      eligible: (m['eligible'] ?? true) as bool,
    );
  }

  Employee copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? email,
    String? phone,
    String? accessCode,
    EmployeeStatus? status,
    String? ssn,
    String? dob,
    String? gender,
    String? dateOfHire,
    String? tobacco,
    String? mobilePhone,
    String? homePhone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? zip,
    String? jobTitle,
    String? benefitClass,
    String? employmentStatus,
    bool? eligible,
  }) =>
      Employee(
        id: id,
        firstName: firstName ?? this.firstName,
        middleName: middleName ?? this.middleName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        accessCode: accessCode ?? this.accessCode,
        status: status ?? this.status,
        createdAt: createdAt,
        ssn: ssn ?? this.ssn,
        dob: dob ?? this.dob,
        gender: gender ?? this.gender,
        dateOfHire: dateOfHire ?? this.dateOfHire,
        tobacco: tobacco ?? this.tobacco,
        mobilePhone: mobilePhone ?? this.mobilePhone,
        homePhone: homePhone ?? this.homePhone,
        addressLine1: addressLine1 ?? this.addressLine1,
        addressLine2: addressLine2 ?? this.addressLine2,
        city: city ?? this.city,
        state: state ?? this.state,
        zip: zip ?? this.zip,
        jobTitle: jobTitle ?? this.jobTitle,
        benefitClass: benefitClass ?? this.benefitClass,
        employmentStatus: employmentStatus ?? this.employmentStatus,
        eligible: eligible ?? this.eligible,
      );
}
