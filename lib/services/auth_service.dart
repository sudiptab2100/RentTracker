import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/app_config.dart';

/// Thrown for user-facing auth errors with a friendly [message].
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Wraps [FirebaseAuth] and exposes the three supported sign-in methods
/// (email/password, Google, phone OTP) plus owner-profile bootstrapping.
class AuthService {
  AuthService(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  bool _googleInitialized = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ---- Email / password ---------------------------------------------------

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _ensureOwnerDoc(cred.user);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      await _ensureOwnerDoc(cred.user, displayName: displayName.trim());
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  // ---- Google -------------------------------------------------------------

  Future<UserCredential> signInWithGoogle() async {
    if (!AppConfig.hasGoogleConfig) {
      throw AuthException(
        'Google Sign-In is not configured. Add your Web client ID to '
        'lib/core/app_config.dart (see SETUP.md).',
      );
    }
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize(serverClientId: AppConfig.googleServerClientId);
        _googleInitialized = true;
      }
      final GoogleSignInAccount account = await google.authenticate();
      final GoogleSignInAuthentication auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw AuthException('Google Sign-In failed: no ID token was returned.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final cred = await _auth.signInWithCredential(credential);
      await _ensureOwnerDoc(cred.user);
      return cred;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthException('Google Sign-In was cancelled.');
      }
      throw AuthException('Google Sign-In failed: ${e.description ?? e.code.name}');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  // ---- Phone (OTP) --------------------------------------------------------

  /// Starts phone verification. On Android, [onAutoVerify] may fire when the
  /// SMS is auto-retrieved; otherwise [codeSent] provides a verificationId to
  /// pair with the user-entered SMS code via [signInWithSmsCode].
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(AuthException error) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerify,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      forceResendingToken: resendToken,
      verificationCompleted: onAutoVerify,
      verificationFailed: (e) => onError(AuthException(_mapAuthError(e))),
      codeSent: (verificationId, token) => codeSent(verificationId, token),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> signInWithSmsCode(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await signInWithPhoneCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final cred = await _auth.signInWithCredential(credential);
      await _ensureOwnerDoc(cred.user);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  // ---- Session ------------------------------------------------------------

  Future<void> signOut() async {
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {/* ignore */}
    }
    await _auth.signOut();
  }

  Future<void> _ensureOwnerDoc(User? user, {String? displayName}) async {
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'displayName': displayName?.isNotEmpty == true
          ? displayName
          : (user.displayName ?? ''),
      'email': user.email ?? '',
      'phone': user.phoneNumber ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect.';
      case 'invalid-phone-number':
        return 'That phone number is not valid.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}
