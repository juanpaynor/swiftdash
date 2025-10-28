import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../services/auth_service.dart';
import '../widgets/modern_widgets.dart';
import '../constants/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Background animation controllers
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    
    // Background animation - slow, subtle floating effect
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

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
      
      final response = await AuthService.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Calculate elapsed time and wait for remaining time if needed
      final elapsed = DateTime.now().difference(startTime);
      final remainingTime = const Duration(milliseconds: 2500) - elapsed;
      if (remainingTime.inMilliseconds > 0) {
        await Future.delayed(remainingTime);
      }
      
      if (response.user != null) {
        if (!mounted) return;
        
        // Close loading overlay
        Navigator.of(context).pop();
        
        HapticFeedback.lightImpact();
        ModernToast.success(context: context, message: 'Welcome back!');
        
        // Small delay before navigation for toast to show
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        context.go('/location-selection');
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

  Future<void> _signInWithGoogle() async {
    // Placeholder - Google Sign In to be implemented
    HapticFeedback.lightImpact();
    ModernToast.info(
      context: context,
      message: 'Google Sign In coming soon!',
    );
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
                'Signing you in...',
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
      backgroundColor: Colors.white, // Pure white background
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 60),

                              // BIGGER LOGO with gradient brand colors
                              Center(
                                child: Column(
                                  children: [
                                    // Enhanced floating logo animation
                                    AnimatedBuilder(
                                      animation: _backgroundAnimation,
                                      builder: (context, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                            0,
                                            -8 + (_backgroundAnimation.value * 16),
                                          ),
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        width: 140, // BIGGER: 80 → 140
                                        height: 140, // BIGGER: 80 → 140
                                        padding: const EdgeInsets.all(20), // Increased padding
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
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Image.asset(
                                            'assets/images/swiftdash_logo.png',
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 40),
                                    
                                    // Modern gradient welcome text
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
                                        'Welcome back',
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
                                      'Sign in to continue your journey',
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

                              // Clean minimal form
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Email field
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Email',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
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
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: TextFormField(
                                            controller: _emailController,
                                            keyboardType: TextInputType.emailAddress,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Enter your email',
                                              hintStyle: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                color: AppTheme.textTertiary,
                                              ),
                                              prefixIcon: Icon(
                                                Icons.email_outlined,
                                                color: AppTheme.primaryBlue.withOpacity(0.6),
                                                size: 22,
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 18,
                                                horizontal: 16,
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
                                            validator: (value) {
                                              if (value == null || value.isEmpty) return 'Please enter your email';
                                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Please enter a valid email';
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),

                                    // Password field
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Password',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
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
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: TextFormField(
                                            controller: _passwordController,
                                            obscureText: !_isPasswordVisible,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Enter your password',
                                              hintStyle: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                color: AppTheme.textTertiary,
                                              ),
                                              prefixIcon: Icon(
                                                Icons.lock_outline,
                                                color: AppTheme.primaryBlue.withOpacity(0.6),
                                                size: 22,
                                              ),
                                              suffixIcon: IconButton(
                                                onPressed: () {
                                                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                                                  HapticFeedback.selectionClick();
                                                },
                                                icon: Icon(
                                                  _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                  color: AppTheme.primaryBlue.withOpacity(0.6),
                                                  size: 22,
                                                ),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 18,
                                                horizontal: 16,
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
                                            validator: (value) {
                                              if (value == null || value.isEmpty) return 'Please enter your password';
                                              if (value.length < 6) return 'Password must be at least 6 characters';
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),
                                    
                                    // Forgot password
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => ModernToast.info(context: context, message: 'Password reset feature coming soon!'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                                        ),
                                        child: ShaderMask(
                                          shaderCallback: (bounds) => LinearGradient(
                                            colors: [
                                              AppTheme.primaryBlue,
                                              AppTheme.accentCyan,
                                            ],
                                          ).createShader(bounds),
                                          child: Text(
                                            'Forgot password?',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 36),
                                    
                                    // Sign in button with gradient
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
                                        onPressed: _isLoading ? null : _login,
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
                                                'Sign In',
                                                style: GoogleFonts.inter(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5,
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
                                    
                                    // Google Sign In button
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
                                        onPressed: _isLoading ? null : _signInWithGoogle,
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
                                    
                                    // Sign up link
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account? ",
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            context.go('/signup');
                                          },
                                          child: ShaderMask(
                                            shaderCallback: (bounds) => LinearGradient(
                                              colors: [
                                                AppTheme.primaryBlue,
                                                AppTheme.accentCyan,
                                              ],
                                            ).createShader(bounds),
                                            child: Text(
                                              'Sign Up',
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      );
                    },
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