import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/app_service.dart';
import '../services/notification_service.dart';
import '../theme/daily_portal_theme.dart';
import 'admin_dashboard.dart';
import 'branch_dashboard.dart';
import 'employee_portal.dart';
import 'request_admin_dashboard.dart';

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
  bool _idleCatAwake = false;
  Timer? _idleStartTimer;
  Timer? _idleBlinkTimer;
  Timer? _clockTimer;
  Timer? _weatherTimer;
  DateTime _now = DateTime.now();
  double? _temperature;
  int? _weatherCode;
  bool _weatherLoading = true;
  int? _previewWeekday;

  String? errorMessage;

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final AnimationController _rainController;
  late final Animation<double> _heroEntrance;
  late final Animation<double> _formEntrance;
  bool _loginImagesPrecached = false;

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
    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _heroEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, .72, curve: Curves.easeOutCubic),
    );
    _formEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(.18, 1, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();
    _startDateTimeAndWeather();
    _restoreSession();
  }

  void _startDateTimeAndWeather() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadWeather();
    _weatherTimer =
        Timer.periodic(const Duration(minutes: 30), (_) => _loadWeather());
  }

  Future<void> _loadWeather() async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '5.6436',
        'longitude': '100.4890',
        'current': 'temperature_2m,weather_code',
        'timezone': 'Asia/Kuala_Lumpur',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Weather service returned ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      if (!mounted || current == null) return;
      setState(() {
        _temperature = (current['temperature_2m'] as num?)?.toDouble();
        _weatherCode = (current['weather_code'] as num?)?.round();
        _weatherLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  void _startIdleCatCycle() {
    _idleStartTimer?.cancel();
    _idleBlinkTimer?.cancel();
    _idleStartTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || loading) return;
      setState(() => _idleCatAwake = true);
      _idleBlinkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted || loading) return;
        setState(() => _idleCatAwake = !_idleCatAwake);
      });
    });
  }

  void _stopIdleCatCycle() {
    _idleStartTimer?.cancel();
    _idleBlinkTimer?.cancel();
    _idleCatAwake = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loginImagesPrecached) return;
    _loginImagesPrecached = true;
    precacheImage(const AssetImage('assets/login_natural_tree.png'), context);
  }

  Future<void> _restoreSession() async {
    try {
      await service.restore();

      if (!mounted) return;

      final user = service.currentUser;

      if (user != null) {
        _openCorrectPortal(user);
      }
    } catch (_) {
      // Session restoration failure is handled by the normal login flow.
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    _rainController.dispose();
    _idleStartTimer?.cancel();
    _idleBlinkTimer?.cancel();
    _clockTimer?.cancel();
    _weatherTimer?.cancel();
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
    _stopIdleCatCycle();

    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty) {
      _showError(
        'Please enter your username or Employee ID.',
      );
      _startIdleCatCycle();
      return;
    }

    if (password.isEmpty) {
      _showError(
        'Please enter your password.',
      );
      _startIdleCatCycle();
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

        _startIdleCatCycle();

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

        if (mounted) _startIdleCatCycle();

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

        _startIdleCatCycle();

        return;
      }

      setState(() {
        loading = false;
      });

      // Request-admin accounts do not represent an employee or branch device.
      // Notification setup must never prevent a successful login.
      if (!user.isRequestAdmin) {
        try {
          await NotificationService.registerCurrentDevice(
            employeeId: user.employeeId,
            branchId: user.branchId,
          );
        } catch (_) {
          // Device notification registration is best-effort.
        }
      }

      _openCorrectPortal(user);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;

        errorMessage = 'Unable to connect to the payroll server. '
            'Please check your connection and try again.';
      });
      _startIdleCatCycle();
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
          builder: (_) => user.staffScope == 'requests'
              ? const RequestAdminDashboard()
              : const AdminDashboard(),
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
    return _DailyLoginTheme.forWeekday(
      kDebugMode && _previewWeekday != null
          ? _previewWeekday!
          : DateTime.now().weekday,
    );
  }

  @override
  Widget build(BuildContext context) => _sevenDayLoginPage(context);

  Widget _sevenDayLoginPage(BuildContext context) {
    final theme = _todayTheme;

    return Scaffold(
      backgroundColor: theme.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              theme.backgroundAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.pageGradient,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: theme.isLight ? .05 : .20),
                    theme.pageBackground.withValues(alpha: .18),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -120,
            bottom: -150,
            child: _loginGlow(theme.accent1, 430),
          ),
          Positioned(
            right: -130,
            top: -160,
            child: _loginGlow(theme.accent2, 430),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 880;
                if (compact) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            _sevenDayTopbar(theme, compact: true),
                            const SizedBox(height: 20),
                            _sevenDayAuthCard(theme, compact: true),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: theme.day == 'Thursday' ? 12 : 11,
                      child: _sevenDayVisual(theme),
                    ),
                    Expanded(
                      flex: theme.day == 'Thursday' ? 8 : 9,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              theme.pageBackground.withValues(
                                alpha: theme.isLight ? .16 : .24,
                              ),
                            ],
                          ),
                          border: Border(
                            left: BorderSide(
                              color: Colors.white.withValues(alpha: .18),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 42,
                          vertical: 26,
                        ),
                        child: Column(
                          children: [
                            _sevenDayTopbar(theme),
                            const SizedBox(height: 18),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 520),
                                    child: _sevenDayAuthCard(theme),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (kDebugMode)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: SafeArea(child: _weekdayPreviewSelector()),
            ),
        ],
      ),
    );
  }

  Widget _weekdayPreviewSelector() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selected = _previewWeekday ?? DateTime.now().weekday;

    return Center(
      child: Material(
        color: const Color(0xE6111825),
        elevation: 12,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < days.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(days[index]),
                      selected: selected == index + 1,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor: _todayTheme.accent1,
                      backgroundColor: Colors.white.withValues(alpha: .08),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .15),
                      ),
                      labelStyle: TextStyle(
                        color: selected == index + 1
                            ? const Color(0xFF08111F)
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) {
                        setState(() => _previewWeekday = index + 1);
                      },
                    ),
                  ),
                IconButton(
                  tooltip: 'Use today automatically',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _previewWeekday = null),
                  icon: const Icon(
                    Icons.today_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sevenDayVisual(_DailyLoginTheme theme) {
    final visualForeground = theme.visualForeground;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: theme.isLight ? .04 : .18),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned(
          left: 48,
          top: 58,
          right: 42,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                theme.kicker,
                style: TextStyle(
                  color: visualForeground.withValues(alpha: .70),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                theme.headline,
                style: TextStyle(
                  color: visualForeground,
                  fontSize: 34,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 13),
              Container(width: 46, height: 3, color: theme.accent1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sevenDayTopbar(
    _DailyLoginTheme theme, {
    bool compact = false,
  }) {
    final foreground = theme.foreground;
    return Row(
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.accent1, theme.accent2],
            ),
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
            boxShadow: [
              BoxShadow(
                color: theme.accent1.withValues(alpha: .28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            color: Colors.white,
            size: compact ? 19 : 22,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(_now).toUpperCase(),
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${DateFormat('dd MMMM yyyy').format(_now)}  •  ${DateFormat('hh:mm:ss a').format(_now)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground.withValues(alpha: .65),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: theme.accent1.withValues(alpha: theme.isLight ? .10 : .16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.accent1.withValues(alpha: .32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 27 : 30,
                height: compact ? 27 : 30,
                decoration: BoxDecoration(
                  color: theme.accent1.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _weatherIcon(_weatherCode),
                  color: theme.accent1,
                  size: compact ? 17 : 19,
                ),
              ),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _weatherLoading
                        ? 'Loading...'
                        : _temperature == null
                            ? '--°C'
                            : '${_temperature!.round()}°C',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _weatherDescription(_weatherCode),
                    style: TextStyle(
                      color: foreground.withValues(alpha: .66),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sevenDayAuthCard(
    _DailyLoginTheme theme, {
    bool compact = false,
  }) {
    final foreground = theme.foreground;
    final fieldColor = theme.isLight
        ? Colors.white.withValues(alpha: .30)
        : Colors.white.withValues(alpha: .10);
    final fieldText = theme.isLight ? const Color(0xFF10294D) : Colors.white;

    InputDecoration decoration(String label, IconData icon) {
      final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: foreground.withValues(alpha: .15)),
      );
      return InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: fieldText.withValues(alpha: .58)),
        prefixIcon: Icon(icon, color: theme.accent1, size: 20),
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.accent1, width: 1.7),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: EdgeInsets.all(compact ? 23 : 34),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.isLight
                  ? [
                      Colors.white.withValues(alpha: .48),
                      Colors.white.withValues(alpha: .18),
                    ]
                  : [
                      Colors.white.withValues(alpha: .16),
                      const Color(0xFF101722).withValues(alpha: .26),
                    ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: theme.isLight ? .68 : .22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: theme.isLight ? .15 : .38),
                blurRadius: 54,
                spreadRadius: -10,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: theme.accent1.withValues(alpha: .12),
                blurRadius: 28,
                spreadRadius: -8,
                offset: const Offset(-8, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _logo(compact: compact),
              SizedBox(height: compact ? 18 : 24),
              Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                theme.cardMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground.withValues(alpha: .65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: usernameController,
                enabled: !loading,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(color: fieldText, fontWeight: FontWeight.w600),
                decoration: decoration(
                  'Username / Employee ID',
                  Icons.person_outline_rounded,
                ),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: passwordController,
                enabled: !loading,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(color: fieldText, fontWeight: FontWeight.w600),
                onSubmitted: (_) {
                  if (!loading) _login();
                },
                decoration:
                    decoration('Password', Icons.lock_outline_rounded).copyWith(
                  suffixIcon: IconButton(
                    tooltip:
                        obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: loading
                        ? null
                        : () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: foreground.withValues(alpha: .65),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : _showForgotPasswordDialog,
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (errorMessage != null) _premiumError(errorMessage!),
              const SizedBox(height: 10),
              SizedBox(
                height: 55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [theme.buttonStart, theme.buttonEnd],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.3,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('SIGN IN',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .7)),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 21),
              Row(
                children: [
                  Expanded(
                      child: Divider(color: foreground.withValues(alpha: .18))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      theme.footer,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .58),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                      child: Divider(color: foreground.withValues(alpha: .18))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 14, color: foreground.withValues(alpha: .58)),
                  const SizedBox(width: 6),
                  Text(
                    'Protected  •  Reliable  •  Hasani Books',
                    style: TextStyle(
                      color: foreground.withValues(alpha: .58),
                      fontSize: 10,
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

  Widget _premiumLoginPage(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: Stack(children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071525),
                  Color(0xFF152A45),
                  Color(0xFF08111F)
                ],
              ),
            ),
          ),
        ),
        Positioned(
            left: -150,
            bottom: -160,
            child: _premiumGlow(460, const Color(0xFF2455C3))),
        Positioned(
            right: -140,
            top: -150,
            child: _premiumGlow(430, const Color(0xFFF2C15A))),
        Positioned.fill(
            child: IgnorePointer(
                child: CustomPaint(painter: _PremiumLoginPainter()))),
        SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 850;
            final form = _premiumLoginCard(compact: compact);
            if (compact) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: form),
                ),
              );
            }
            return Row(children: [
              Expanded(
                flex: 11,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(68, 58, 40, 58),
                  child: _premiumHero(),
                ),
              ),
              Expanded(
                flex: 9,
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(40), child: form)),
              ),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _premiumHero() => Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -68,
            top: 28,
            bottom: 18,
            child: Opacity(
              opacity: .34,
              child: Image.asset('assets/login_natural_tree.png',
                  width: 420, fit: BoxFit.contain),
            ),
          ),
          const Positioned(
            top: 8,
            left: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOOD WORK.\nBRIGHTER\nTOMORROW.',
                    style: TextStyle(
                        color: Color(0xFFD7DEEA),
                        fontSize: 15,
                        height: 1.8,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 18),
                SizedBox(
                    width: 52,
                    child: Divider(color: Color(0xFFF2C15A), thickness: 3)),
              ],
            ),
          ),
          const Positioned(
            left: 8,
            bottom: 0,
            child: _PremiumFeature(Icons.eco_outlined, 'Growing together'),
          ),
        ],
      );

  Widget _premiumLoginCard({required bool compact}) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 44, vertical: compact ? 30 : 40),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: const Color(0xFFF2C15A).withValues(alpha: .50)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 45,
                    offset: Offset(0, 22))
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/hasani_books_logo.jpg',
                  width: compact ? 220 : 255,
                  errorBuilder: (context, error, stackTrace) => const Text(
                      'HASANI BOOKS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28))),
              const SizedBox(height: 34),
              const Text('Welcome Back',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text('Sign in to continue',
                  style: TextStyle(color: Color(0xFFC5CED9))),
              const SizedBox(height: 28),
              _premiumInput(usernameController, 'Username / Employee ID',
                  Icons.person_outline_rounded,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus()),
              const SizedBox(height: 15),
              _premiumInput(
                  passwordController, 'Password', Icons.lock_outline_rounded,
                  password: true, onSubmitted: (_) {
                if (!loading) _login();
              }),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : _showForgotPasswordDialog,
                  child: const Text('Forgot password?',
                      style: TextStyle(
                          color: Color(0xFFF2C15A),
                          fontWeight: FontWeight.w700)),
                ),
              ),
              if (errorMessage != null) _premiumError(errorMessage!),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : _login,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Color(0xFF08111F), strokeWidth: 2.5))
                      : const Icon(Icons.login_rounded),
                  label: Text(loading ? 'SIGNING IN...' : 'LOGIN',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2C15A),
                    foregroundColor: const Color(0xFF08111F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_outlined, color: Color(0xFFF2C15A), size: 16),
                SizedBox(width: 7),
                Text('Protected • Reliable • Hasani Books',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ]),
          ),
        ),
      );

  Widget _premiumError(String message) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
            color: const Color(0xFFFFE8EC),
            borderRadius: BorderRadius.circular(12)),
        child: Text(message,
            style: const TextStyle(
                color: Color(0xFF9B1028), fontWeight: FontWeight.w700)),
      );

  Widget _premiumInput(
          TextEditingController controller, String hint, IconData icon,
          {bool password = false, ValueChanged<String>? onSubmitted}) =>
      TextField(
        controller: controller,
        enabled: !loading,
        obscureText: password && obscurePassword,
        onSubmitted: onSubmitted,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFAEB8C5)),
          prefixIcon: Icon(icon, color: const Color(0xFFF2C15A)),
          suffixIcon: password
              ? IconButton(
                  onPressed: loading
                      ? null
                      : () =>
                          setState(() => obscurePassword = !obscurePassword),
                  icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white70),
                )
              : null,
          filled: true,
          fillColor: Colors.black.withValues(alpha: .20),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0x33FFFFFF))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFF2C15A), width: 1.5)),
        ),
      );

  Widget _premiumGlow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: .16),
              blurRadius: 150,
              spreadRadius: 55)
        ]),
      );

  Widget _legacyLoginPage(BuildContext context) {
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

              if (!compact)
                Positioned(
                  right: 18,
                  bottom: 0,
                  width: 390,
                  height: math.min(constraints.maxHeight - 20, 650),
                  child: _companyTreeForToday(theme),
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
                                  child: const SizedBox.shrink(),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (!compact && loading)
                Positioned(
                  width: 390,
                  top: constraints.maxHeight * .27,
                  right: 18,
                  bottom: 0,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _WateringPainter(
                        animation: _rainController,
                        color: const Color(0xFF74D7FF),
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

  Widget _companyTreeForToday(_DailyLoginTheme theme) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year);
    return _companyTreeCard(
      theme,
      dayNumber: now.difference(firstDay).inDays + 1,
      daysInYear: DateTime(now.year + 1).difference(firstDay).inDays,
      year: now.year,
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
          child: ClipRect(
            child: Transform.translate(
              offset: const Offset(0, 48),
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

              SizedBox(height: compact ? 14 : 18),
              _dateTimeWeatherStrip(theme, compact: compact),
              SizedBox(height: compact ? 17 : 21),

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

  Widget _dateTimeWeatherStrip(
    _DailyLoginTheme theme, {
    required bool compact,
  }) {
    final weather = _weatherDescription(_weatherCode);
    final weatherIcon = _weatherIcon(_weatherCode);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 15,
        vertical: compact ? 10 : 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF130B24).withValues(alpha: .32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined,
              color: theme.accent1, size: compact ? 18 : 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(_now).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMMM yyyy').format(_now)}  •  '
                  '${DateFormat('hh:mm:ss a').format(_now)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withValues(alpha: .22),
          ),
          Icon(weatherIcon,
              color: const Color(0xFFFFD56A), size: compact ? 21 : 24),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _weatherLoading
                    ? 'Loading...'
                    : _temperature == null
                        ? '--°C'
                        : '${_temperature!.round()}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              Text(
                weather,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _weatherDescription(int? code) {
    if (code == null) return _weatherLoading ? 'Sungai Petani' : 'Unavailable';
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Rain';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }

  IconData _weatherIcon(int? code) {
    if (code == null) return Icons.cloud_outlined;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code <= 3) return Icons.cloud_queue;
    if (code == 45 || code == 48) return Icons.blur_on;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.water_drop_outlined;
    }
    if (code >= 95) return Icons.thunderstorm_outlined;
    return Icons.cloud_outlined;
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
          'assets/hasani_books_logo.jpg',
          fit: BoxFit.contain,
          cacheWidth: 1200,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.business_rounded,
            color: Color(0xFF263B91),
            size: 46,
          ),
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

class _PremiumFeature extends StatelessWidget {
  const _PremiumFeature(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .10)),
          ),
          child: Icon(icon, color: const Color(0xFFF2C15A), size: 20),
        ),
        const SizedBox(width: 9),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ]);
}

class _PremiumLoginPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = const Color(0x22F2C15A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final blue = Paint()
      ..color = const Color(0x224B7BEC)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height * .2)
          ..quadraticBezierTo(size.width * .3, size.height * .05,
              size.width * .6, size.height * .14)
          ..quadraticBezierTo(size.width * .82, size.height * .2, size.width,
              size.height * .08),
        gold);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height * .82)
          ..quadraticBezierTo(size.width * .3, size.height * .7,
              size.width * .52, size.height * .84)
          ..quadraticBezierTo(size.width * .78, size.height * .98, size.width,
              size.height * .76),
        blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WateringPainter extends CustomPainter {
  _WateringPainter({required this.animation, required this.color})
      : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rainPaint = Paint()
      ..color = color.withValues(alpha: .48)
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: .10)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 46; i++) {
      final column = ((i * 47) % 101) / 100;
      final phase = (animation.value + i * .137) % 1.0;
      final x = column * size.width;
      final y = phase * (size.height + 60) - 45;
      final length = 10.0 + (i % 5) * 2.4;
      final start = Offset(x, y);
      final end = Offset(x - 2.5, y + length);
      canvas.drawLine(start, end, glowPaint);
      canvas.drawLine(start, end, rainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WateringPainter oldDelegate) =>
      oldDelegate.color != color;
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

  bool get isLight =>
      day == 'Monday' ||
      day == 'Tuesday' ||
      day == 'Thursday' ||
      day == 'Friday';

  Color get foreground => isLight ? const Color(0xFF10294D) : Colors.white;

  Color get visualForeground => day == 'Thursday' ? Colors.white : foreground;

  String get backgroundAsset => 'assets/login_days/${day.toLowerCase()}.png';

  Color get pageBackground {
    switch (day) {
      case 'Monday':
        return const Color(0xFFDCEAF4);
      case 'Tuesday':
        return const Color(0xFFF5F7FB);
      case 'Thursday':
        return const Color(0xFFF4F7FB);
      case 'Friday':
        return const Color(0xFFEDF5F3);
      case 'Saturday':
        return const Color(0xFF100D22);
      case 'Wednesday':
        return const Color(0xFF080807);
      default:
        return const Color(0xFF08111F);
    }
  }

  Color get panelBackground => pageBackground.withValues(alpha: .97);

  Color get cardBackground => isLight
      ? Colors.white.withValues(alpha: day == 'Monday' ? .58 : .92)
      : const Color(0xFF121722).withValues(alpha: day == 'Sunday' ? .86 : .91);

  List<Color> get pageGradient {
    switch (day) {
      case 'Monday':
        return const [Color(0xFFC9E0F0), Color(0xFFEDF6FB)];
      case 'Tuesday':
        return const [Color(0xFFF8FAFC), Color(0xFFE8EDF4)];
      case 'Wednesday':
        return const [Color(0xFF050505), Color(0xFF211C13)];
      case 'Thursday':
        return const [Color(0xFF062C54), Color(0xFFF5F8FC)];
      case 'Friday':
        return const [Color(0xFFD7E9E3), Color(0xFFF5FAF8)];
      case 'Saturday':
        return const [Color(0xFF0B1023), Color(0xFF2B1742)];
      default:
        return const [Color(0xFF071525), Color(0xFF17273A)];
    }
  }

  List<Color> get visualGradient {
    switch (day) {
      case 'Monday':
        return const [Color(0xFFBEDAEA), Color(0xFFE8F3F8)];
      case 'Tuesday':
        return const [Color(0xFFF9FAFC), Color(0xFFE5EBF1)];
      case 'Wednesday':
        return const [Color(0xFF050505), Color(0xFF2A2418)];
      case 'Thursday':
        return const [Color(0xFF06294F), Color(0xFF0D6096)];
      case 'Friday':
        return const [Color(0xFFE8F3EF), Color(0xFFC9DED7)];
      case 'Saturday':
        return const [Color(0xFF080B19), Color(0xFF392352)];
      default:
        return const [Color(0xFF07111C), Color(0xFF14283A)];
    }
  }

  String get kicker {
    switch (day) {
      case 'Monday':
        return 'SAME VISION • BRIGHTER TOMORROW';
      case 'Tuesday':
        return 'PEOPLE • PROCESS • PROGRESS';
      case 'Wednesday':
        return 'DISCIPLINE • FOCUS • GROWTH';
      case 'Thursday':
        return 'GREAT TEAMS • GREAT THINGS';
      case 'Friday':
        return 'FOCUS • EXECUTE • ACHIEVE';
      case 'Saturday':
        return 'A BRIGHTER TOMORROW • TOGETHER';
      default:
        return 'PEOPLE • PROCESS • PROGRESS';
    }
  }

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
          accent2: Color(0xFF2A86FF),
          buttonStart: Color(0xFF2A86FF),
          buttonEnd: Color(0xFF0B67F5),
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
          accent1: Color(0xFF0C2C59),
          accent2: Color(0xFF58789E),
          buttonStart: Color(0xFF183F74),
          buttonEnd: Color(0xFF0C2C59),
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
          accent1: Color(0xFF1E8CFF),
          accent2: Color(0xFF0866F5),
          buttonStart: Color(0xFF1E8CFF),
          buttonEnd: Color(0xFF0866F5),
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
          accent1: Color(0xFF12A06F),
          accent2: Color(0xFF087D58),
          buttonStart: Color(0xFF12A06F),
          buttonEnd: Color(0xFF087D58),
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
          accent1: Color(0xFFCA4BF0),
          accent2: Color(0xFF6748FF),
          buttonStart: Color(0xFF6748FF),
          buttonEnd: Color(0xFFE04AEF),
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
          accent1: Color(0xFFF5CF75),
          accent2: Color(0xFFD9AD55),
          buttonStart: Color(0xFFF5CF75),
          buttonEnd: Color(0xFFD9AD55),
        );
    }
  }
}
