import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'otp_page.dart';

/// Step 1 of registration — user enters their email to receive a signup OTP.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AuthProvider>();
    provider.clearMessages();

    final success =
        await provider.requestSignupOtp(_emailController.text.trim());

    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpPage(email: _emailController.text.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Back Button ─────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: theme.colorScheme.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Icon ────────────────────────────────
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.3),
                              theme.colorScheme.secondary.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: theme.colorScheme.primary,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Title ────────────────────────────────
                    Center(
                      child: Text(
                        'Create Account',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 24,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        "Enter your email to get started.\nWe'll send you a one-time code.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Step Indicator ──────────────────────
                    _StepIndicator(currentStep: 1),
                    const SizedBox(height: 32),

                    // ── Email Field ─────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Patient Email Address',
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        prefixIcon: Icon(Icons.email_outlined,
                            color: theme.colorScheme.primary, size: 20),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: theme.colorScheme.error.withOpacity(0.5)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email is required';
                        }
                        final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(val.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Info Card ────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: theme.colorScheme.secondary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A verification code will be sent to this email. '
                              'You will fill in patient & caregiver details in the next step.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.secondary
                                    .withOpacity(0.85),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Error Message ───────────────────────
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.errorMessage == null) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: theme.colorScheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Send OTP Button ─────────────────────
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        return SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed:
                                auth.isLoading ? null : _handleRequestOtp,
                            icon: auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              auth.isLoading ? 'Sending…' : 'Send Verification Code',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Already have account ────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: theme.textTheme.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () {
                            context.read<AuthProvider>().clearMessages();
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step Progress Indicator ──────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _StepDot(number: 1, label: 'Email', isActive: currentStep >= 1, theme: theme),
        _StepLine(isActive: currentStep >= 2, theme: theme),
        _StepDot(number: 2, label: 'Details', isActive: currentStep >= 2, theme: theme),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;
  final ThemeData theme;
  const _StepDot({
    required this.number,
    required this.label,
    required this.isActive,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.15),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : theme.colorScheme.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.3),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool isActive;
  final ThemeData theme;
  const _StepLine({required this.isActive, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
    );
  }
}
