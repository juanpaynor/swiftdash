import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../services/auth_service.dart';
import '../widgets/modern_widgets.dart';
import '../constants/app_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate() || !_acceptTerms) {
      if (!_acceptTerms) {
        HapticFeedback.mediumImpact();
        ModernToast.error(
          context: context,
          message: 'Please accept the terms and conditions',
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();
    
    // Show loading overlay
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _buildLoadingOverlay(),
    );
    
    try {
      // Start timer for minimum loading display (2.5 seconds)
      final startTime = DateTime.now();
      
      final response = await AuthService.signUpWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Create user profile in database
        await AuthService.createUserProfile(
          userId: response.user!.id,
          firstName: _nameController.text.trim(),
          lastName: '',
          phoneNumber: _phoneController.text.trim(),
        );

        // Calculate elapsed time and wait for remaining time if needed
        final elapsed = DateTime.now().difference(startTime);
        final remainingTime = const Duration(milliseconds: 2500) - elapsed;
        if (remainingTime.inMilliseconds > 0) {
          await Future.delayed(remainingTime);
        }

        if (!mounted) return;
        
        // Close loading overlay
        Navigator.of(context).pop();
        
        HapticFeedback.lightImpact();

        // Show success message
        ModernToast.success(
          context: context,
          message: 'Account created! Please check your email to verify.',
        );
        
        // Small delay before navigation
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        context.go('/login');
      } else {
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        // Close loading overlay
        Navigator.of(context).pop();
        ModernToast.error(context: context, message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie animation
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.asset(
                'assets/lottie/login_loading.json',
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Loading text with gradient
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  AppTheme.primaryBlue,
                  AppTheme.accentCyan,
                ],
              ).createShader(bounds),
              child: Text(
                'Creating your account...',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white, // Will be masked by gradient
                  letterSpacing: 0.2,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Please wait',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),

                      // BIGGER logo section with gradient branding
                      Center(
                        child: Column(
                          children: [
                            // BIGGER SwiftDash logo (140x140 to match login)
                            Container(
                              width: 140,
                              height: 140,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryBlue.withOpacity(0.1),
                                    AppTheme.accentCyan.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.15),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withOpacity(0.12),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: AppTheme.accentCyan.withOpacity(0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/swiftdash_logo.png',
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                              ),
                            ),

                            const SizedBox(height: 40),
                            
                            // Gradient "Join SwiftDash" text (bigger)
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  AppTheme.primaryBlue,
                                  AppTheme.accentCyan,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'Join SwiftDash',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.8,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            Text(
                              'Create your account to get started',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.1,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 56),

                      // Clean form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Full Name field
                            _buildTextField(
                              label: 'Full Name',
                              controller: _nameController,
                              icon: Icons.person_outline,
                              hint: 'Enter your full name',
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your full name';
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Email field
                            _buildTextField(
                              label: 'Email',
                              controller: _emailController,
                              icon: Icons.email_outlined,
                              hint: 'Enter your email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your email';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Phone field
                            _buildTextField(
                              label: 'Phone Number',
                              controller: _phoneController,
                              icon: Icons.phone_outlined,
                              hint: 'Enter your phone number',
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your phone number';
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Password field
                            _buildTextField(
                              label: 'Password',
                              controller: _passwordController,
                              icon: Icons.lock_outline,
                              hint: 'Create a password',
                              isPassword: true,
                              isPasswordVisible: _isPasswordVisible,
                              onTogglePassword: () {
                                setState(() => _isPasswordVisible = !_isPasswordVisible);
                                HapticFeedback.selectionClick();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter a password';
                                if (value.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Confirm Password field
                            _buildTextField(
                              label: 'Confirm Password',
                              controller: _confirmPasswordController,
                              icon: Icons.lock_outline,
                              hint: 'Re-enter your password',
                              isPassword: true,
                              isPasswordVisible: _isConfirmPasswordVisible,
                              onTogglePassword: () {
                                setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                                HapticFeedback.selectionClick();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please confirm your password';
                                if (value != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),
                            
                            // Terms and conditions checkbox
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _acceptTerms,
                                    onChanged: (value) {
                                      setState(() => _acceptTerms = value ?? false);
                                      HapticFeedback.selectionClick();
                                    },
                                    activeColor: AppTheme.primaryBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _acceptTerms = !_acceptTerms);
                                      HapticFeedback.selectionClick();
                                    },
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textSecondary,
                                        ),
                                        children: [
                                          const TextSpan(text: 'I agree to the '),
                                          TextSpan(
                                            text: 'Terms & Conditions',
                                            style: GoogleFonts.inter(
                                              color: AppTheme.primaryBlue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: GoogleFonts.inter(
                                              color: AppTheme.primaryBlue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 36),
                            
                            // Create account button with gradient (BIGGER)
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppTheme.primaryBlue,
                                    AppTheme.accentCyan,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: AppTheme.accentCyan.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: GoogleFonts.inter(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 28),
                            
                            // Divider with "OR"
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          AppTheme.borderColor.withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary.withOpacity(0.6),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.borderColor.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 28),
                            
                            // Google Sign In button placeholder
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.borderColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : () {
                                  // Placeholder - Google Sign In to be implemented
                                  HapticFeedback.lightImpact();
                                  ModernToast.info(
                                    context: context,
                                    message: 'Google Sign In coming soon!',
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.textPrimary,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/google_logo.png',
                                      width: 24,
                                      height: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 36),
                            
                            // Sign in link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.go('/login');
                                  },
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        AppTheme.primaryBlue,
                                        AppTheme.accentCyan,
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Sign In',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white, // This will be masked by the gradient
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String? Function(String?) validator,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.borderColor.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && !isPasswordVisible,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.textTertiary.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                icon,
                color: AppTheme.primaryBlue.withOpacity(0.5),
                size: 22,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.primaryBlue.withOpacity(0.5),
                        size: 22,
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 18,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.primaryBlue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.errorColor,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.errorColor,
                  width: 2,
                ),
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}
