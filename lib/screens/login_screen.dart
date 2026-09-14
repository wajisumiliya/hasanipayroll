import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../theme/daily_portal_theme.dart';
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

  Future<void> _showForgotPasswordDialog() async {
    final username =
        TextEditingController(text: usernameController.text.trim());
    final identity = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    String? resetToken;
    String? dialogError;
    bool submitting = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final completed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (submitting) return;
            if (resetToken == null) {
              if (username.text.trim().isEmpty ||
                  identity.text.trim().isEmpty) {
                setDialogState(
                    () => dialogError = 'Enter your username and IC number.');
                return;
              }
              setDialogState(() {
                submitting = true;
                dialogError = null;
              });
              final result = await service.verifyForgotPasswordIdentity(
                username: username.text,
                identityNumber: identity.text,
              );
              if (!dialogContext.mounted) return;
              setDialogState(() {
                submitting = false;
                if (result['ok'] == true && result['resetToken'] != null) {
                  resetToken = result['resetToken'].toString();
                } else {
                  dialogError = result['message']?.toString() ??
                      'The details entered do not match.';
                }
              });
              return;
            }

            if (newPassword.text.length < 8) {
              setDialogState(() =>
                  dialogError = 'Password must contain at least 8 characters.');
              return;
            }
            if (newPassword.text != confirmPassword.text) {
              setDialogState(() => dialogError = 'New passwords do not match.');
              return;
            }
            setDialogState(() {
              submitting = true;
              dialogError = null;
            });
            final result = await service.resetForgottenPassword(
              resetToken: resetToken!,
              newPassword: newPassword.text,
            );
            if (!dialogContext.mounted) return;
            if (result['ok'] == true) {
              Navigator.of(dialogContext).pop(true);
            } else {
              setDialogState(() {
                submitting = false;
                dialogError = result['message']?.toString() ??
                    'Unable to reset your password.';
              });
            }
          }

          InputDecoration fieldDecoration(String label, IconData icon) =>
              InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon),
                  border: const OutlineInputBorder());

          return AlertDialog(
            title: Text(
                resetToken == null ? 'Forgot Password' : 'Create New Password'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(resetToken == null
                      ? 'Verify your account using the IC number in your employee record.'
                      : 'Identity verified. Choose a new password for your account.'),
                  const SizedBox(height: 18),
                  if (resetToken == null) ...[
                    TextField(
                        controller: username,
                        enabled: !submitting,
                        decoration: fieldDecoration(
                            'Username / Employee ID', Icons.person_outline)),
                    const SizedBox(height: 14),
                    TextField(
                        controller: identity,
                        enabled: !submitting,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                        decoration:
                            fieldDecoration('IC Number', Icons.badge_outlined)),
                  ] else ...[
                    TextField(
                        controller: newPassword,
                        enabled: !submitting,
                        obscureText: obscureNew,
                        decoration:
                            fieldDecoration('New Password', Icons.lock_outline)
                                .copyWith(
                                    suffixIcon: IconButton(
                                        onPressed: () => setDialogState(
                                            () => obscureNew = !obscureNew),
                                        icon: Icon(obscureNew
                                            ? Icons.visibility
                                            : Icons.visibility_off)))),
                    const SizedBox(height: 14),
                    TextField(
                        controller: confirmPassword,
                        enabled: !submitting,
                        obscureText: obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                        decoration: fieldDecoration(
                                'Confirm New Password', Icons.lock_reset)
                            .copyWith(
                                suffixIcon: IconButton(
                                    onPressed: () => setDialogState(
                                        () => obscureConfirm = !obscureConfirm),
                                    icon: Icon(obscureConfirm
                                        ? Icons.visibility
                                        : Icons.visibility_off)))),
                  ],
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(dialogError!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL')),
              FilledButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(resetToken == null
                          ? 'VERIFY IDENTITY'
                          : 'RESET PASSWORD')),
            ],
          );
        },
      ),
    );
    username.dispose();
    identity.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    if (completed == true && mounted) {
      passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Password reset successfully. Sign in with your new password.'),
        backgroundColor: Colors.green,
      ));
    }
  }

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
  // UI — DAILY GLASSMORPHISM THEMES
  // ============================================================

  _DailyLoginTheme get _todayTheme {
    // DateTime.weekday: Monday = 1 ... Sunday = 7.
    return _DailyLoginTheme.forWeekday(DateTime.now().weekday);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _todayTheme;

    return Scaffold(
      backgroundColor: theme.background.first,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: theme.background,
                      stops: const [0, .52, 1],
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: PortalAtmosphere(theme: DailyPortalTheme.today()),
              ),

              // Large animated ambient glows
              Positioned(
                top: -190,
                left: compact ? -210 : -80,
                child: _floatingGlow(
                  theme.accent1,
                  compact ? 450 : 650,
                  44,
                ),
              ),
              Positioned(
                right: compact ? -240 : -120,
                bottom: -260,
                child: _floatingGlow(
                  theme.accent2,
                  compact ? 500 : 680,
                  -38,
                ),
              ),

              // Soft diagonal light streaks
              Positioned(
                top: 38,
                left: -100,
                right: compact ? 70 : 510,
                child: Transform.rotate(
                  angle: -.10,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          theme.accent1.withValues(alpha: .95),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 55,
                right: -100,
                left: compact ? 100 : 700,
                child: Transform.rotate(
                  angle: -.12,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          theme.accent2.withValues(alpha: .92),
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
                      compact ? 20 : 32,
                      compact ? 18 : 40,
                      compact ? 110 : 95,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: compact
                          ? Column(
                              children: [
                                _entrance(
                                  _mobileBranding(theme),
                                  _heroEntrance,
                                  -24,
                                ),
                                const SizedBox(height: 18),
                                _entrance(
                                  _glassLoginCard(theme, compact: true),
                                  _formEntrance,
                                  30,
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 9,
                                  child: _entrance(
                                    _glassLoginCard(theme),
                                    _formEntrance,
                                    -42,
                                  ),
                                ),
                                const SizedBox(width: 56),
                                Expanded(
                                  flex: 11,
                                  child: _entrance(
                                    _desktopCatHero(
                                      theme,
                                      height: (constraints.maxHeight - 90)
                                          .clamp(480.0, 720.0),
                                      bottomExtension: 95,
                                      screenRightGap: math.max(
                                        0,
                                        (constraints.maxWidth - 1180) / 2,
                                      ),
                                    ),
                                    _heroEntrance,
                                    42,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _desktopCatHero(
    _DailyLoginTheme theme, {
    required double height,
    required double bottomExtension,
    required double screenRightGap,
  }) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year);
    final dayNumber = now.difference(firstDay).inDays + 1;
    final daysInYear = DateTime(now.year + 1).difference(firstDay).inDays;

    return Transform.translate(
      offset: Offset(0, bottomExtension),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Transform.translate(
                offset: const Offset(-155, 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Image.asset(
                    loading
                        ? 'assets/login_cat_open_eyes.png'
                        : 'assets/login_cat_cutout.png',
                    key: ValueKey(loading),
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, error, __) => Center(
                      child: Icon(
                        Icons.pets_rounded,
                        size: 180,
                        color: theme.accent1.withValues(alpha: .8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -screenRightGap + 18,
              bottom: 0,
              width: 400,
              height: math.min(height, 590),
              child: _companyTreeCard(
                theme,
                dayNumber: dayNumber,
                daysInYear: daysInYear,
                year: now.year,
              ),
            ),
            if (loading)
              Positioned(
                left: -40,
                right: -screenRightGap,
                top: -bottomExtension,
                bottom: 0,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _WateringPainter(
                      animation: _ambientController,
                      color: const Color(0xFF74D7FF),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _companyTreeCard(
    _DailyLoginTheme theme, {
    required int dayNumber,
    required int daysInYear,
    required int year,
  }) {
    final progress = (dayNumber / daysInYear).clamp(.01, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 58, 8, 0),
          child: Transform.scale(
            scale: .30 + progress * .70,
            alignment: Alignment.bottomCenter,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const RadialGradient(
                radius: .74,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, .73, 1],
              ).createShader(bounds),
              child: Image.asset(
                'assets/login_natural_tree.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                'GROWING TOGETHER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .92),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DAY $dayNumber / $daysInYear  •  TREE $year',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileBranding(_DailyLoginTheme theme) {
    return Column(
      children: [
        _dayPill(theme),
        const SizedBox(height: 15),
        Text(
          theme.headline.replaceAll('\n', ' '),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          theme.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .82),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _dayPill(_DailyLoginTheme theme) {
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
              color: Colors.white.withValues(alpha: .22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.accent1,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.accent1.withValues(alpha: .55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '${theme.day.toUpperCase()}  •  HASANI WORKHUB',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassLoginCard(
    _DailyLoginTheme theme, {
    bool compact = false,
  }) {
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
              color: Colors.white.withValues(alpha: .40),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .28),
                blurRadius: 60,
                offset: const Offset(0, 28),
              ),
              BoxShadow(
                color: theme.accent1.withValues(alpha: .16),
                blurRadius: 36,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IMPORTANT:
              // This is YOUR EXISTING Hasani Books logo asset.
              // No generated book logo and no HB logo is used.
              _logo(compact: compact),

              SizedBox(height: compact ? 19 : 24),

              const Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                theme.cardMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .76),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 28),

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
                  theme,
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
                  theme,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip:
                        obscurePassword ? 'Show password' : 'Hide password',
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
                      color: theme.buttonEnd,
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              if (errorMessage != null) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8EC).withValues(alpha: .94),
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
              ],

              const SizedBox(height: 22),

              SizedBox(
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        theme.buttonStart,
                        theme.buttonEnd,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.buttonEnd.withValues(alpha: .38),
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

              const SizedBox(height: 21),

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
                      theme.footer,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
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

              const SizedBox(height: 16),

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
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: .80),
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
          // SAME EXISTING LOGO USED BY YOUR ORIGINAL LOGIN SCREEN
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

  InputDecoration _inputDecoration(String label, IconData icon,
      [_DailyLoginTheme? dailyTheme]) {
    final radius = BorderRadius.circular(15);
    final theme = dailyTheme ?? _todayTheme;

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF637394),
      ),
      prefixIcon: Icon(
        icon,
        color: theme.buttonEnd,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .90),
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
          color: Colors.white.withValues(alpha: .80),
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
        borderSide: BorderSide(
          color: theme.accent1,
          width: 2,
        ),
      ),
    );
  }
}

class _WateringPainter extends CustomPainter {
  _WateringPainter({required this.animation, required this.color})
      : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rainPaint = Paint()
      ..color = color.withValues(alpha: .68)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: .16)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 72; i++) {
      final column = ((i * 47) % 101) / 100;
      final speed = .78 + (i % 7) * .065;
      final phase = (animation.value * 10 * speed + i * .137) % 1.0;
      final x = column * size.width;
      final y = phase * (size.height + 90) - 70;
      final length = 12.0 + (i % 5) * 3.5;
      final start = Offset(x, y);
      final end = Offset(x - 4, y + length);
      canvas.drawLine(start, end, glowPaint);
      canvas.drawLine(start, end, rainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WateringPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CompanyTreePainter extends CustomPainter {
  const _CompanyTreePainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * .985;
    final centerX = size.width * .5;
    final treeHeight = size.height * (.38 + progress * .46);
    final topY = groundY - treeHeight;
    final trunk = Paint()
      ..color = const Color(0xFF8C5B38)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7 + progress * 5;

    final trunkPath = Path()
      ..moveTo(centerX, groundY)
      ..cubicTo(centerX - 5, groundY - treeHeight * .35, centerX + 7,
          groundY - treeHeight * .68, centerX, topY);
    canvas.drawPath(trunkPath, trunk);

    final branchCount = 3 + (progress * 5).floor();
    for (var i = 0; i < branchCount; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final startY = groundY - treeHeight * (.35 + i * .075);
      final length =
          size.width * (.16 + progress * .13) * (1 - i / (branchCount * 2.2));
      final end = Offset(centerX + side * length, startY - treeHeight * .18);
      final branch = Path()
        ..moveTo(centerX, startY)
        ..quadraticBezierTo(
          centerX + side * length * .42,
          startY - treeHeight * .04,
          end.dx,
          end.dy,
        );
      canvas.drawPath(
        branch,
        trunk
          ..strokeWidth = 3.2 + progress * 2
          ..color = const Color(0xFF96613B),
      );
    }

    final leafCount = 5 + (progress * 34).floor();
    for (var i = 0; i < leafCount; i++) {
      final angle = i * 2.399963;
      final radius = math.sqrt((i + 1) / leafCount);
      final crownWidth = size.width * (.17 + progress * .27);
      final crownHeight = treeHeight * (.20 + progress * .25);
      final leafCenter = Offset(
        centerX + math.cos(angle) * crownWidth * radius,
        topY + crownHeight * .56 + math.sin(angle) * crownHeight * radius,
      );
      final leafRadius = 4.0 + progress * 3.2;
      final leafPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFF69B96B),
          accent,
          (i % 5) * .055,
        )!
            .withValues(alpha: .92);
      canvas.drawOval(
        Rect.fromCenter(
          center: leafCenter,
          width: leafRadius * 1.55,
          height: leafRadius * 2.15,
        ),
        leafPaint,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, groundY + 3),
        width: size.width * .55,
        height: 9,
      ),
      Paint()..color = Colors.black.withValues(alpha: .18),
    );
  }

  @override
  bool shouldRepaint(covariant _CompanyTreePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _DailyLoginTheme {
  const _DailyLoginTheme({
    required this.day,
    required this.headline,
    required this.message,
    required this.cardMessage,
    required this.footer,
    required this.background,
    required this.accent1,
    required this.accent2,
    required this.buttonStart,
    required this.buttonEnd,
  });

  final String day;
  final String headline;
  final String message;
  final String cardMessage;
  final String footer;
  final List<Color> background;
  final Color accent1;
  final Color accent2;
  final Color buttonStart;
  final Color buttonEnd;

  static _DailyLoginTheme forWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return const _DailyLoginTheme(
          day: 'Monday',
          headline: 'Focused Minds\nBuild Great Weeks',
          message: 'A focused mind creates extraordinary days.',
          cardMessage: 'Start strong. Your week begins here.',
          footer: 'FOCUS  •  PEOPLE  •  PROGRESS',
          background: [
            Color(0xFF10091D),
            Color(0xFF35204D),
            Color(0xFF24162F),
          ],
          accent1: Color(0xFFF0D28B),
          accent2: Color(0xFF9C7AC2),
          buttonStart: Color(0xFFE6C171),
          buttonEnd: Color(0xFF7A4D8C),
        );
      case DateTime.tuesday:
        return const _DailyLoginTheme(
          day: 'Tuesday',
          headline: 'Kind Energy,\nClear Progress',
          message: 'Small steps create great progress.',
          cardMessage: 'Welcome back. Keep your momentum moving.',
          footer: 'KINDNESS  •  CLARITY  •  ACTION',
          background: [
            Color(0xFF110A1D),
            Color(0xFF38203E),
            Color(0xFF4B213E),
          ],
          accent1: Color(0xFFE8C778),
          accent2: Color(0xFFA76D86),
          buttonStart: Color(0xFFDBB25F),
          buttonEnd: Color(0xFF80465F),
        );
      case DateTime.wednesday:
        return const _DailyLoginTheme(
          day: 'Wednesday',
          headline: 'Progress Looks\nGood on You',
          message: 'Halfway there. Keep moving forward.',
          cardMessage: 'Your consistent effort is making a difference.',
          footer: 'GROWTH  •  BALANCE  •  PROGRESS',
          background: [
            Color(0xFF0C111D),
            Color(0xFF233D43),
            Color(0xFF171D2D),
          ],
          accent1: Color(0xFFE7C77E),
          accent2: Color(0xFF668A91),
          buttonStart: Color(0xFFDDBB68),
          buttonEnd: Color(0xFF476A70),
        );
      case DateTime.thursday:
        return const _DailyLoginTheme(
          day: 'Thursday',
          headline: 'Consistency\nCreates Results',
          message: 'Better days are built by consistent effort.',
          cardMessage: 'Stay steady. Achievement is getting closer.',
          footer: 'CONSISTENCY  •  PURPOSE  •  RESULTS',
          background: [
            Color(0xFF10091D),
            Color(0xFF43254E),
            Color(0xFF291531),
          ],
          accent1: Color(0xFFE8C778),
          accent2: Color(0xFF986FA9),
          buttonStart: Color(0xFFDFB964),
          buttonEnd: Color(0xFF73477F),
        );
      case DateTime.friday:
        return const _DailyLoginTheme(
          day: 'Friday',
          headline: 'Finish Strong,\nFinish Proud',
          message: 'Finish strong. You make it happen.',
          cardMessage: 'One final push toward a rewarding week.',
          footer: 'PURPOSE  •  PRIDE  •  ACHIEVEMENT',
          background: [
            Color(0xFF0D0A12),
            Color(0xFF382C1D),
            Color(0xFF18121E),
          ],
          accent1: Color(0xFFF3D994),
          accent2: Color(0xFFB98A3D),
          buttonStart: Color(0xFFE7C673),
          buttonEnd: Color(0xFF9B6D2D),
        );
      case DateTime.saturday:
        return const _DailyLoginTheme(
          day: 'Saturday',
          headline: 'Bright Energy,\nFresh Opportunity',
          message: 'Good energy brings great opportunities.',
          cardMessage: 'Balance your work. Enjoy your journey.',
          footer: 'ENERGY  •  BALANCE  •  OPPORTUNITY',
          background: [
            Color(0xFF0B1020),
            Color(0xFF263858),
            Color(0xFF171F35),
          ],
          accent1: Color(0xFFE6C579),
          accent2: Color(0xFF687DA5),
          buttonStart: Color(0xFFDAB765),
          buttonEnd: Color(0xFF4D6085),
        );
      default:
        return const _DailyLoginTheme(
          day: 'Sunday',
          headline: 'Rest, Reset,\nRise Again',
          message: 'A calm mind is a powerful mind.',
          cardMessage: 'Rest, reset, and prepare to shine.',
          footer: 'REFLECT  •  RECHARGE  •  RENEW',
          background: [
            Color(0xFF0E0B18),
            Color(0xFF2D2942),
            Color(0xFF191525),
          ],
          accent1: Color(0xFFEAD39A),
          accent2: Color(0xFF80739A),
          buttonStart: Color(0xFFDEC481),
          buttonEnd: Color(0xFF625675),
        );
    }
  }
}
