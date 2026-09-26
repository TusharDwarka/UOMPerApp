import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over Firebase Authentication.
///
/// Passwords are never stored by this app — not locally, not in Firestore.
/// They are sent over TLS to Firebase Auth, which stores only a salted,
/// memory-hard hash (a modified scrypt). The app only ever holds a
/// short-lived ID token, refreshed automatically by the SDK.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get user => _auth.authStateChanges();

  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> signUpWithEmail(String email, String password, {String? displayName}) async {
    final current = _auth.currentUser;
    UserCredential cred;
    if (current != null && current.isAnonymous) {
      // Upgrade the guest account in place so its data keeps the same uid.
      cred = await current.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
    } else {
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
    }
    // A linked guest keeps an "anonymous" token until refreshed; the
    // Firestore rules for groups check the sign-in provider.
    await cred.user?.getIdToken(true);
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {
      // Verification is a nicety; don't block sign-up on it.
    }
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email);

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name.trim());
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() => _auth.signOut();

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password';
        case 'email-already-in-use':
        case 'credential-already-in-use':
          return 'An account already exists with this email';
        case 'invalid-email':
          return 'Invalid email address';
        case 'weak-password':
          return 'Password is too weak (use 8+ characters)';
        case 'too-many-requests':
          return 'Too many attempts. Try again in a few minutes.';
        case 'network-request-failed':
          return 'No internet connection';
        default:
          return e.message ?? 'Authentication failed';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
