import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();

  ConfirmationResult? _confirmationResult;

  void _signUpWithEmail() async {
    if (_passwordController.text == _confirmPasswordController.text) {
      try {
        final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        // Send email verification
        if (userCredential.user != null && !userCredential.user!.emailVerified) {
          await userCredential.user!.sendEmailVerification();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A verification email has been sent. Please check your inbox.'),
            ),
          );
        }
        context.go('/home');
      } on FirebaseAuthException catch (e) {
        print(e.message);
      }
    } else {
      print('Passwords do not match');
    }
  }

  void _sendVerificationCode() async {
    try {
      // For web, signInWithPhoneNumber will handle the reCAPTCHA UI automatically.
      // For mobile, it will send an SMS directly.
      _confirmationResult = await _auth.signInWithPhoneNumber(_phoneController.text);
      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  void _verifyCode() async {
    try {
      final UserCredential userCredential = await _confirmationResult!.confirm(_smsController.text);
      print("Signed in with phone number: ${userCredential.user!.uid}");
      context.go('/home');
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _signUpWithEmail,
                child: const Text('Sign Up with Email'),
              ),
              const SizedBox(height: 32.0),
              const Divider(),
              const SizedBox(height: 32.0),
              if (_confirmationResult == null)
                Column(
                  children: [
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _sendVerificationCode,
                      child: const Text('Send Verification Code'),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    TextField(
                      controller: _smsController,
                      decoration: const InputDecoration(
                        labelText: 'Verification Code',
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _verifyCode,
                      child: const Text('Verify and Sign Up'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
