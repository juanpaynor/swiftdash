import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/modern_widgets.dart';
import '../constants/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();
    try {
      final response = await AuthService.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (response.user != null) {
        if (!mounted) return;
        HapticFeedback.lightImpact();
        ModernToast.success(context: context, message: 'Welcome back!');
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(context: context, message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color.fromARGB(255, 63, 152, 211), Color.fromARGB(255, 61, 89, 214)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppTheme.spacing32),

                        // Logo + Title
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radius28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.delivery_dining_rounded, size: 50, color: AppTheme.primaryBlue),
                          ),
                        ),

                        const SizedBox(height: AppTheme.spacing16),
                        Text('Welcome to', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 18, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('SwiftDash', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0, height: 1.0)),
                        const SizedBox(height: 8),
                        Text('Lightning Fast • Ultra Reliable', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500, letterSpacing: 0.3)),

                        const SizedBox(height: AppTheme.spacing32),

                        // Card with form
                        ModernCard(
                          padding: const EdgeInsets.all(AppTheme.spacing28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Sign In', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.8)),
                                const SizedBox(height: AppTheme.spacing32),

                                ModernTextField(
                                  label: 'Email Address',
                                  hintText: 'Enter your email',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Please enter your email';
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Please enter a valid email';
                                    return null;
                                  },
                                ),

                                const SizedBox(height: AppTheme.spacing20),
                                ModernTextField(
                                  label: 'Password',
                                  hintText: 'Enter your password',
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  onSuffixIconTap: () {
                                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                                    HapticFeedback.selectionClick();
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Please enter your password';
                                    if (value.length < 6) return 'Password must be at least 6 characters';
                                    return null;
                                  },
                                ),

                                const SizedBox(height: AppTheme.spacing16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => ModernToast.info(context: context, message: 'Password reset feature coming soon!'),
                                    child: Text('Forgot Password?', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spacing24),
                                ModernButton(text: 'Sign In', onPressed: _isLoading ? null : _login, isLoading: _isLoading, width: double.infinity),
                                const SizedBox(height: AppTheme.spacing24),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("Don't have an account? ", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                                      GestureDetector(
                                        onTap: () { HapticFeedback.lightImpact(); context.go('/signup'); },
                                        child: Text('Sign Up', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}