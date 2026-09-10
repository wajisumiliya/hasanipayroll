import 'dart:math' as math;
import 'dart:ui';

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
  late final AnimationController _catWalkController;
  late final Animation<double> _heroEntrance;
  late final Animation<double> _formEntrance;
  String _activeFeature = 'People';

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
    _catWalkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
    _catWalkController.dispose();
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
                                  flex: 11,
                                  child: _entrance(
                                    _desktopBranding(theme),
                                    _heroEntrance,
                                    -42,
                                  ),
                                ),
                                const SizedBox(width: 56),
                                Expanded(
                                  flex: 9,
                                  child: _entrance(
                                    _glassLoginCard(theme),
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
              _catActivity(constraints.maxWidth, compact),
            ],
          );
        },
      ),
    );
  }

  Widget _catActivity(double screenWidth, bool compact) {
    final catWidth = compact ? 160.0 : 210.0;
    final catHeight = compact ? 116.0 : 150.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: compact ? 8 : 12,
      height: catHeight,
      child: IgnorePointer(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _catWalkController,
            builder: (context, child) {
              final progress = _catWalkController.value;
              final movingRight =
                  _catWalkController.status == AnimationStatus.reverse;
              final horizontal = (screenWidth - catWidth) * (1 - progress);
              final step = math.sin(progress * math.pi * 24).abs() * 3;
              final playing = _activeFeature == 'Attendance';

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: playing ? 0 : horizontal,
                    bottom: step,
                    width: playing ? screenWidth : catWidth,
                    height: catHeight,
                    child: CustomPaint(
                      painter: playing
                          ? _PlayingCatsPainter(progress)
                          : _WalkingCatPainter(
                              progress: progress,
                              facingRight: movingRight,
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _desktopBranding(_DailyLoginTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _dayPill(theme),
          const SizedBox(height: 30),
          Text(
            theme.headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 55,
              height: .99,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [theme.accent1, theme.accent2],
              ),
            ),
          ),
          const SizedBox(height: 21),
          Text(
            theme.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _GlassFeature(
                Icons.people_alt_outlined,
                'People',
                theme.accent1,
                selected: _activeFeature == 'People',
                onTap: () => setState(() => _activeFeature = 'People'),
              ),
              _GlassFeature(
                Icons.calendar_month_outlined,
                'Attendance',
                theme.accent1,
                selected: _activeFeature == 'Attendance',
                onTap: () => setState(() => _activeFeature = 'Attendance'),
              ),
              _GlassFeature(
                Icons.account_balance_wallet_outlined,
                'Payroll',
                theme.accent1,
                selected: _activeFeature == 'Payroll',
                onTap: () => setState(() => _activeFeature = 'Payroll'),
              ),
            ],
          ),
        ],
      ),
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

class _GlassFeature extends StatelessWidget {
  const _GlassFeature(
    this.icon,
    this.label,
    this.accent, {
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label animation',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: selected ? .22 : .10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: .85)
                      : Colors.white.withValues(alpha: .18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: accent),
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
        ),
      ),
    );
  }
}

/// A code-drawn cat stays crisp and visible on every background. The previous
/// raster frames included a baked-in checkerboard, which hid the cat at the
/// small size used along the bottom of the login page.
class _WalkingCatPainter extends CustomPainter {
  const _WalkingCatPainter({required this.progress, required this.facingRight});

  final double progress;
  final bool facingRight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (facingRight) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    _CatPainter.drawCat(canvas, size, const Color(0xFFF2A65A),
        legPhase: progress * math.pi * 24);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WalkingCatPainter oldDelegate) =>
      progress != oldDelegate.progress || facingRight != oldDelegate.facingRight;
}

class _PlayingCatsPainter extends CustomPainter {
  const _PlayingCatsPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final catSize = Size(math.min(150.0, size.width * .22), size.height);
    final center = size.width / 2;
    final bounce = math.sin(progress * math.pi * 4).abs();

    canvas.save();
    canvas.translate(center - catSize.width - 34, 0);
    canvas.scale(-1, 1);
    canvas.translate(-catSize.width, 0);
    _CatPainter.drawCat(canvas, catSize, const Color(0xFFF2A65A),
        legPhase: progress * math.pi * 16);
    canvas.restore();

    canvas.save();
    canvas.translate(center + 34, 0);
    _CatPainter.drawCat(canvas, catSize, const Color(0xFFE8E5DF),
        legPhase: progress * math.pi * 16 + math.pi);
    canvas.restore();

    final ballCenter = Offset(
      center + math.sin(progress * math.pi * 2) * 62,
      size.height - 29 - bounce * 34,
    );
    final ball = Paint()..color = const Color(0xFFFFC857);
    canvas.drawCircle(ballCenter, 15, ball);
    final seam = Paint()
      ..color = const Color(0xFF7B4D9B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(Rect.fromCircle(center: ballCenter, radius: 11), 0, math.pi,
        false, seam);
    canvas.drawArc(Rect.fromCircle(center: ballCenter, radius: 11), math.pi,
        math.pi, false, seam);
  }

  @override
  bool shouldRepaint(covariant _PlayingCatsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _CatPainter {
  static void drawCat(Canvas canvas, Size size, Color color,
      {required double legPhase}) {
    final scale = math.min(size.width / 180, size.height / 120);
    canvas.translate((size.width - 180 * scale) / 2, size.height - 112 * scale);
    canvas.scale(scale, scale);
    final fur = Paint()..color = color;
    final dark = Paint()..color = const Color(0xFF49313A);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(const Rect.fromLTWH(20, 100, 145, 10), shadow);
    canvas.drawOval(const Rect.fromLTWH(47, 35, 105, 58), fur);
    canvas.drawCircle(const Offset(42, 48), 30, fur);
    final ears = Path()
      ..moveTo(19, 27)
      ..lineTo(25, 0)
      ..lineTo(43, 22)
      ..moveTo(47, 20)
      ..lineTo(62, 2)
      ..lineTo(67, 32);
    canvas.drawPath(ears, fur);
    canvas.drawCircle(const Offset(31, 43), 3.5, dark);
    canvas.drawCircle(const Offset(50, 43), 3.5, dark);
    final nose = Paint()..color = const Color(0xFFE46B76);
    canvas.drawCircle(const Offset(39, 53), 3, nose);
    final stride = math.sin(legPhase) * 7;
    final legs = Paint()
      ..color = color
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(66, 79), Offset(61 + stride, 103), legs);
    canvas.drawLine(Offset(91, 81), Offset(96 - stride, 103), legs);
    canvas.drawLine(Offset(124, 78), Offset(119 + stride, 103), legs);
    canvas.drawLine(Offset(143, 73), Offset(148 - stride, 101), legs);
    final tail = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(const Rect.fromLTWH(135, 16, 38, 60), -1.2, 2.1, false, tail);
    final whisker = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..strokeWidth = 1.4;
    canvas.drawLine(const Offset(17, 54), const Offset(0, 49), whisker);
    canvas.drawLine(const Offset(18, 59), const Offset(0, 62), whisker);
  }
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
