import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../widgets/walking_cat.dart';
import 'admin_dashboard.dart';
import 'branch_dashboard.dart';
import 'employee_portal.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AppService service = AppService.instance;

  final TextEditingController usernameController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  String? errorMessage;

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final Animation<double> _heroEntrance;
  late final Animation<double> _formEntrance;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    _heroEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, .72, curve: Curves.easeOutCubic),
    );
    _formEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(.18, 1, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      await service.restore();

      if (!mounted) return;

      final user = service.currentUser;

      if (user != null) {
        _openCorrectPortal(user);
      }
    } catch (e) {
      debugPrint('Session restore error: $e');
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty) {
      _showError(
        'Please enter your username or Employee ID.',
      );
      return;
    }

    if (password.isEmpty) {
      _showError(
        'Please enter your password.',
      );
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await service.login(
        username,
        password,
      );

      if (!mounted) return;

      // ==========================================================
      // LOGIN FAILED
      // ==========================================================

      if (result != null && result != 'FIRST_LOGIN_PASSWORD_REQUIRED') {
        setState(() {
          loading = false;
          errorMessage = result;
        });

        return;
      }

      // ==========================================================
      // FIRST LOGIN
      //
      // The backend/app service has detected that the employee
      // must create a new password before opening the dashboard.
      // ==========================================================

      if (result == 'FIRST_LOGIN_PASSWORD_REQUIRED') {
        setState(() {
          loading = false;
        });

        await _showFirstLoginPasswordDialog();

        return;
      }

      // ==========================================================
      // NORMAL LOGIN SUCCESS
      // ==========================================================

      final user = service.currentUser;

      if (user == null) {
        setState(() {
          loading = false;

          errorMessage =
              'Login succeeded, but your account information could not be loaded.';
        });

        return;
      }

      setState(() {
        loading = false;
      });

      _openCorrectPortal(user);
    } catch (e) {
      debugPrint('Login error: $e');

      if (!mounted) return;

      setState(() {
        loading = false;

        errorMessage = 'Unable to connect to the payroll server. '
            'Please check your connection and try again.';
      });
    }
  }

  // ============================================================
  // FIRST LOGIN PASSWORD CHANGE
  // ============================================================

  Future<void> _showFirstLoginPasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool savingPassword = false;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> savePassword() async {
                final newPassword = newPasswordController.text;
                final confirmPassword = confirmPasswordController.text;

                if (newPassword.length < 8) {
                  setDialogState(() {
                    dialogError =
                        'Password must contain at least 8 characters.';
                  });
                  return;
                }

                if (newPassword != confirmPassword) {
                  setDialogState(() {
                    dialogError = 'New passwords do not match.';
                  });
                  return;
                }

                if (newPassword == passwordController.text) {
                  setDialogState(() {
                    dialogError =
                        'Your new password must be different from the default password.';
                  });
                  return;
                }

                setDialogState(() {
                  savingPassword = true;
                  dialogError = null;
                });

                final result = await service.completeFirstLogin(newPassword);

                if (!mounted || !dialogContext.mounted) return;

                if (result != null) {
                  setDialogState(() {
                    savingPassword = false;
                    dialogError = result;
                  });
                  return;
                }

                Navigator.of(dialogContext).pop();
                passwordController.clear();

                final user = service.currentUser;
                if (user != null) {
                  _openCorrectPortal(user);
                }
              }

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.lock_reset_rounded),
                    SizedBox(width: 12),
                    Expanded(child: Text('Create Your New Password')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This is your first login. You must replace the default password before opening your dashboard.',
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: newPasswordController,
                          obscureText: obscureNewPassword,
                          enabled: !savingPassword,
                          autofocus: true,
                          decoration: _inputDecoration(
                            'New Password',
                            Icons.lock_outline,
                          ).copyWith(
                            helperText: 'Use at least 8 characters.',
                            suffixIcon: IconButton(
                              onPressed: () => setDialogState(() {
                                obscureNewPassword = !obscureNewPassword;
                              }),
                              icon: Icon(
                                obscureNewPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPassword,
                          enabled: !savingPassword,
                          onSubmitted: (_) {
                            if (!savingPassword) savePassword();
                          },
                          decoration: _inputDecoration(
                            'Retype New Password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setDialogState(() {
                                obscureConfirmPassword =
                                    !obscureConfirmPassword;
                              }),
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            dialogError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: savingPassword ? null : savePassword,
                            icon: savingPassword
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              savingPassword
                                  ? 'SAVING...'
                                  : 'SAVE PASSWORD & CONTINUE',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: savingPassword
                        ? null
                        : () {
                            service.cancelFirstLoginOtp();
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('CANCEL'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  // ============================================================
  // PORTAL ROUTING
  // ============================================================

  void _openCorrectPortal(dynamic user) {
    if (!mounted) return;

    if (user.isAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AdminDashboard(),
        ),
      );
      return;
    }

    if (user.isBranch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const BranchPortal(),
        ),
      );
      return;
    }

    if (user.isEmployee) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const EmployeePortal(),
        ),
      );
      return;
    }

    setState(() {
      loading = false;

      errorMessage = 'Your account does not have a valid portal role.';
    });
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      errorMessage = message;
    });
  }

  // ============================================================
  // UI — GLASSMORPHISM
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06122D),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

          return Stack(
            children: [
              // Deep blue base
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF071A46),
                        Color(0xFF0A3A87),
                        Color(0xFF08172E),
                      ],
                      stops: [0, .52, 1],
                    ),
                  ),
                ),
              ),

              // Ambient moving light
              Positioned(
                top: -180,
                left: compact ? -180 : -40,
                child: _floatingGlow(
                  const Color(0xFF1C8CFF),
                  compact ? 420 : 620,
                  42,
                ),
              ),
              Positioned(
                right: compact ? -220 : -120,
                bottom: -250,
                child: _floatingGlow(
                  const Color(0xFFFF3148),
                  compact ? 470 : 650,
                  -36,
                ),
              ),

              // Decorative light streaks
              Positioned(
                top: 22,
                left: -80,
                right: compact ? 80 : 500,
                child: Transform.rotate(
                  angle: -.10,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF26B8FF),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                right: -100,
                left: compact ? 100 : 700,
                child: Transform.rotate(
                  angle: -.12,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFFFF2943),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 40,
                      compact ? 22 : 34,
                      compact ? 18 : 40,
                      compact ? 105 : 90,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: compact
                          ? Column(
                              children: [
                                _entrance(
                                  _mobileBranding(),
                                  _heroEntrance,
                                  -24,
                                ),
                                const SizedBox(height: 18),
                                _entrance(
                                  _glassLoginCard(compact: true),
                                  _formEntrance,
                                  30,
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _entrance(
                                    _desktopBranding(),
                                    _heroEntrance,
                                    -42,
                                  ),
                                ),
                                const SizedBox(width: 56),
                                Expanded(
                                  flex: 9,
                                  child: _entrance(
                                    _glassLoginCard(),
                                    _formEntrance,
                                    42,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              // Existing animated cat stays on the login screen
              Positioned(
                left: compact ? 12 : 28,
                right: compact ? 12 : 28,
                bottom: 2,
                child: IgnorePointer(
                  child: WalkingCat(
                    height: compact ? 72 : 88,
                    catCount: 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _desktopBranding() {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _brandPill(),
          const SizedBox(height: 34),
          const Text(
            'A Brighter\nTomorrow,\nTogether',
            style: TextStyle(
              color: Colors.white,
              fontSize: 56,
              height: .98,
              fontWeight: FontWeight.w900,
              letterSpacing: -2.0,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 62,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4CC9FF),
                  Color(0xFFFF304A),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Simple Payroll for a Better Workplace',
            style: TextStyle(
              color: Color(0xFFDDE8FF),
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _GlassFeature(
                Icons.people_alt_outlined,
                'People',
              ),
              _GlassFeature(
                Icons.calendar_month_outlined,
                'Attendance',
              ),
              _GlassFeature(
                Icons.account_balance_wallet_outlined,
                'Payroll',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileBranding() {
    return Column(
      children: [
        _brandPill(),
        const SizedBox(height: 16),
        const Text(
          'A Brighter Tomorrow, Together',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Simple Payroll for a Better Workplace',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFD5E2FF),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _brandPill() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: .20),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: Color(0xFF9DD8FF),
              ),
              SizedBox(width: 8),
              Text(
                'HASANI BOOKS  •  SECURE WORKSPACE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassLoginCard({bool compact = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 28 : 34),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: compact ? 24 : 32,
          sigmaY: compact ? 24 : 32,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 22 : 34),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: compact ? .19 : .16),
            borderRadius: BorderRadius.circular(compact ? 28 : 34),
            border: Border.all(
              color: Colors.white.withValues(alpha: .38),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .30),
                blurRadius: 60,
                offset: const Offset(0, 28),
              ),
              BoxShadow(
                color: const Color(0xFF4C8DFF).withValues(alpha: .14),
                blurRadius: 36,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Exact Hasani Books asset from your current project
              _logo(compact: compact),
              SizedBox(height: compact ? 20 : 26),

              const Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Sign in securely to continue to Hasani Workhub.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .76),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !loading,
                style: const TextStyle(
                  color: Color(0xFF102247),
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration(
                  'Username / Employee ID',
                  Icons.person_outline_rounded,
                ),
                onSubmitted: (_) {
                  FocusScope.of(context).nextFocus();
                },
              ),
              const SizedBox(height: 15),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !loading,
                style: const TextStyle(
                  color: Color(0xFF102247),
                  fontWeight: FontWeight.w600,
                ),
                onSubmitted: (_) {
                  if (!loading) _login();
                },
                decoration: _inputDecoration(
                  'Password',
                  Icons.lock_outline_rounded,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF3157D5),
                    ),
                  ),
                ),
              ),

              if (errorMessage != null) ...[
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 12,
                      sigmaY: 12,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8EC)
                            .withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF8A9A),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFD11835),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF9B1028),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              SizedBox(
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1CA7FF),
                        Color(0xFF075BE8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B6CF2)
                            .withValues(alpha: .38),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: .15),
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.white.withValues(alpha: .32),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'SECURE ACCESS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.white.withValues(alpha: .32),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 17),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 15,
                    color: Colors.white.withValues(alpha: .72),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Protected  •  Reliable  •  Hasani Books',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .70),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo({bool compact = false}) {
    return Center(
      child: Container(
        width: compact ? 220 : 250,
        height: compact ? 88 : 104,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: .75),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Image.asset(
          'assets/hasani_books_logo.jpg',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text(
                'HASANI BOOKS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF173A78),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: .8,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _loginGlow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: .38),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingGlow(
    Color color,
    double size,
    double travel,
  ) {
    return AnimatedBuilder(
      animation: _ambientController,
      child: _loginGlow(color, size),
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(
          _ambientController.value,
        );

        return Transform.translate(
          offset: Offset(
            travel * progress,
            travel * .55 * progress,
          ),
          child: Transform.scale(
            scale: .94 + progress * .08,
            child: child,
          ),
        );
      },
    );
  }

  Widget _entrance(
    Widget child,
    Animation<double> animation,
    double horizontalOffset,
  ) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              horizontalOffset * (1 - animation.value),
              0,
            ),
            child: child,
          );
        },
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    final radius = BorderRadius.circular(15);

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF637394),
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF3157D5),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .88),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: .72),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: .78),
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: .35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(
          color: Color(0xFF48B8FF),
          width: 2,
        ),
      ),
    );
  }
}

class _GlassFeature extends StatelessWidget {
  const _GlassFeature(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: .18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFFAADFFF),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
