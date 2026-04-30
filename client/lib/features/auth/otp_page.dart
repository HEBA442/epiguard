import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

/// Step 2 of registration — OTP + patient profile + caregiver profile.
/// Calls /api/auth/complete-signup on the backend.
class OtpPage extends StatefulWidget {
  final String email;
  const OtpPage({super.key, required this.email});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // OTP controllers (6 individual boxes)
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // Patient fields
  final _patientNameController = TextEditingController();
  final _patientPasswordController = TextEditingController();
  final _patientConfirmPasswordController = TextEditingController();
  final _patientAgeController = TextEditingController();
  final _patientEpilepsyDurationController = TextEditingController();

  // Caregiver fields
  final _caregiverNameController = TextEditingController();
  final _caregiverEmailController = TextEditingController();
  final _caregiverRelationController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _signupSuccess = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _patientNameController.dispose();
    _patientPasswordController.dispose();
    _patientConfirmPasswordController.dispose();
    _patientAgeController.dispose();
    _patientEpilepsyDurationController.dispose();
    _caregiverNameController.dispose();
    _caregiverEmailController.dispose();
    _caregiverRelationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

  Future<void> _handleCompleteSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AuthProvider>();
    provider.clearMessages();

    final success = await provider.completeSignup(
      patientName: _patientNameController.text.trim(),
      patientEmail: widget.email,
      patientPassword: _patientPasswordController.text,
      patientAge: int.parse(_patientAgeController.text.trim()),
      patientEpilepsyDuration: _patientEpilepsyDurationController.text.trim(),
      caregiverName: _caregiverNameController.text.trim(),
      caregiverEmail: _caregiverEmailController.text.trim(),
      caregiverRelation: _caregiverRelationController.text.trim(),
      otpCode: _otpCode,
    );

    if (success && mounted) {
      setState(() => _signupSuccess = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_signupSuccess) {
      return _SuccessScreen(theme: theme);
    }

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Back ───────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: theme.colorScheme.primary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Header ─────────────────────────────
                  Center(
                    child: Text(
                      'Complete Registration',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 22,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Code sent to ${widget.email}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Step Indicator ──────────────────────
                  _buildStepIndicator(theme),
                  const SizedBox(height: 30),

                  // ── OTP Section ─────────────────────────
                  _SectionHeader(
                    icon: Icons.lock_open_rounded,
                    title: 'Verification Code',
                    theme: theme,
                  ),
                  const SizedBox(height: 16),
                  _buildOtpBoxes(theme),
                  const SizedBox(height: 28),

                  // ── Patient Section ─────────────────────
                  _SectionHeader(
                    icon: Icons.person_rounded,
                    title: 'Patient Information',
                    theme: theme,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _patientNameController,
                    label: 'Full Name',
                    icon: Icons.badge_outlined,
                    theme: theme,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _patientPasswordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    theme: theme,
                    isPassword: true,
                    obscure: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Minimum 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _patientConfirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    theme: theme,
                    isPassword: true,
                    obscure: _obscureConfirmPassword,
                    onToggleObscure: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (v) {
                      if (v != _patientPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _patientAgeController,
                    label: 'Age',
                    icon: Icons.cake_outlined,
                    theme: theme,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Age is required';
                      final age = int.tryParse(v.trim());
                      if (age == null || age < 1 || age > 120) {
                        return 'Enter a valid age';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _patientEpilepsyDurationController,
                    label: 'Epilepsy Duration (e.g. "2 years")',
                    icon: Icons.timeline_rounded,
                    theme: theme,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Duration is required'
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // ── Caregiver Section ───────────────────
                  _SectionHeader(
                    icon: Icons.favorite_rounded,
                    title: 'Caregiver Information',
                    theme: theme,
                    accentColor: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _caregiverNameController,
                    label: "Caregiver's Full Name",
                    icon: Icons.person_outline_rounded,
                    theme: theme,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Caregiver name is required"
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _caregiverEmailController,
                    label: "Caregiver's Email",
                    icon: Icons.email_outlined,
                    theme: theme,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Caregiver email is required";
                      }
                      final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _caregiverRelationController,
                    label: 'Relation to Patient (e.g. "Mother")',
                    icon: Icons.group_outlined,
                    theme: theme,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Relation is required'
                        : null,
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
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ── Submit Button ───────────────────────
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed:
                              auth.isLoading ? null : _handleCompleteSignup,
                          icon: auth.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded,
                                  size: 20),
                          label: Text(
                            auth.isLoading
                                ? 'Creating account…'
                                : 'Create My Account',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── OTP Boxes ─────────────────────────────────────────────
  Widget _buildOtpBoxes(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 46,
          height: 56,
          child: TextFormField(
            controller: _otpControllers[i],
            focusNode: _otpFocusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) {
                _otpFocusNodes[i + 1].requestFocus();
              } else if (val.isEmpty && i > 0) {
                _otpFocusNodes[i - 1].requestFocus();
              }
            },
            validator: (_) {
              if (_otpCode.length < 6) {
                return '';
              }
              return null;
            },
          ),
        );
      }),
    );
  }

  // ── Step Indicator ─────────────────────────────────────────
  Widget _buildStepIndicator(ThemeData theme) {
    return Row(
      children: [
        _dot(1, 'Email', true, theme),
        _line(true, theme),
        _dot(2, 'Details', true, theme),
      ],
    );
  }

  Widget _dot(int n, String label, bool active, ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Text(
              '$n',
              style: TextStyle(
                color: active ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.4),
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
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.3),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _line(bool active, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          height: 2,
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
    );
  }

  // ── Generic Text Field ─────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: isPassword ? obscure : false,
      style: TextStyle(color: theme.colorScheme.onSurface),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontSize: 13,
        ),
        prefixIcon:
            Icon(icon, color: theme.colorScheme.primary, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
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
          borderSide:
              BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final ThemeData theme;
  final Color? accentColor;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.theme,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? theme.colorScheme.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: color.withOpacity(0.2),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

// ── Success Screen ─────────────────────────────────────────
class _SuccessScreen extends StatelessWidget {
  final ThemeData theme;
  const _SuccessScreen({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.secondary,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Account Created!',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 24,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your patient and caregiver accounts have been registered successfully. '
                  'You can now sign in.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Pop back to the login screen (pop twice to skip signup_page)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text('Go to Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
