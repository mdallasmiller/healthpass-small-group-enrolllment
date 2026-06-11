import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth for the admin portal.
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  /// Maps Firebase error codes to friendly messages.
  static String describeError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'weak-password':
          return 'Please choose a stronger password (6+ characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please try again shortly.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
