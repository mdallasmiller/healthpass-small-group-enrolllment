import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// The app's Firestore lives in a dedicated named database ("enrollment")
/// inside the shared HealthPass project, fully isolated from the project's
/// default database used by the other apps.
FirebaseFirestore get appDb => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'enrollment',
    );
