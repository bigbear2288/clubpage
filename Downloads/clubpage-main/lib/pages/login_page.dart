import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        final userCredential = await _auth.signInWithPopup(googleProvider);
        _processUserCredential(userCredential);
      } else {
        try {
          final googleProvider = GoogleAuthProvider();
          googleProvider.setCustomParameters({'prompt': 'select_account'});
          final userCredential = await _auth.signInWithProvider(googleProvider);
          _processUserCredential(userCredential);
        } catch (e) {
          debugPrint('signInWithProvider failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sign-in error: ${e.toString()}')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processUserCredential(UserCredential userCredential) async {
    final String? email = userCredential.user?.email;

    // Easter egg for ggoodman26
    if (email == 'ggoodman26@students.hopkins.edu') {
      if (mounted) {
        _showBunnyEasterEgg();
      }
      return;
    }

    if (email == null || !email.endsWith('hopkins.edu')) {
      await _auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access restricted to Hopkins School users only'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) setState(() {});
  }

  void _showBunnyEasterEgg() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🐰',
              style: TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7A1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'You are a bunny!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A1E1E),
            ),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Clubs App',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7A1E1E),
              ),
            ),
            const SizedBox(height: 50),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login),
                        SizedBox(width: 8),
                        Text('Sign in with Google'),
                      ],
                    ),
                  ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
