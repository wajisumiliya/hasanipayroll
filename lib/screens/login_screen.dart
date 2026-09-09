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
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071126),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF071126),
                        Color(0xFF10285A),
                        Color(0xFF070D1C)
                      ],
                      stops: [0, .53, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                  top: -170,
                  right: -100,
                  child: _floatingGlow(const Color(0xFF4169FF), 480, 34)),
              Positioned(
                  bottom: -210,
                  left: compact ? -210 : 80,
                  child: _floatingGlow(const Color(0xFFFF5A61), 500, -30)),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          compact ? 20 : 42, 18, compact ? 20 : 42, 10),
                      child: Row(
                        children: [
                          Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF63E6BE),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 9),
                          const Text('HASANI  /  PEOPLE OS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.7)),
                          const Spacer(),
                          if (!compact) ...[
                            const Icon(Icons.lock_outline_rounded,
                                color: Color(0xFF9DAFD6), size: 16),
                            const SizedBox(width: 7),
                            const Text('Protected workspace',
                                style: TextStyle(
                                    color: Color(0xFF9DAFD6), fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(compact ? 16 : 38, 12,
                              compact ? 16 : 38, compact ? 96 : 30),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1220),
                            child: compact
                                ? Column(
                                    children: [
                                      _entrance(_logo(), _heroEntrance, -24),
                                      const SizedBox(height: 16),
                                      _entrance(_loginCard(compact: true),
                                          _formEntrance, 30),
                                    ],
                                  )
                                : Container(
                                    height: 700,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(36),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: .45)),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x77000000),
                                            blurRadius: 70,
                                            offset: Offset(0, 32))
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(36),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              flex: 12,
                                              child: _entrance(_premiumHero(),
                                                  _heroEntrance, -42)),
                                          Expanded(
                                            flex: 9,
                                            child: Container(
                                              color: const Color(0xFFFAFBFF),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 50,
                                                      vertical: 34),
                                              child: Center(
                                                  child: SingleChildScrollView(
                                                      child: _entrance(
                                                          _loginCard(),
                                                          _formEntrance,
                                                          42))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                  left: 24,
                  right: 24,
                  bottom: 3,
                  child: WalkingCat(height: 88, catCount: 1)),
            ],
          );
        },
      ),
    );
  }

  Widget _loginGlow(Color color, double size) => IgnorePointer(
          child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              color.withValues(alpha: .28),
              color.withValues(alpha: 0)
            ])),
      ));

  Widget _floatingGlow(Color color, double size, double travel) {
    return AnimatedBuilder(
      animation: _ambientController,
      child: _loginGlow(color, size),
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(_ambientController.value);
        return Transform.translate(
          offset: Offset(travel * progress, travel * .6 * progress),
          child: Transform.scale(scale: .94 + progress * .08, child: child),
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
        builder: (context, child) => Transform.translate(
          offset: Offset(horizontalOffset * (1 - animation.value), 0),
          child: child,
        ),
      ),
    );
  }

  Widget _premiumHero() => Container(
        padding: const EdgeInsets.all(48),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3157D5), Color(0xFF162D70), Color(0xFF081329)],
            stops: [0, .52, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -80,
              top: 40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10, width: 35),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(width: 205, child: _logo()),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C8DFF).withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: const Color(0xFF9DB2FF).withValues(alpha: .35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 15, color: Color(0xFFFFD27D)),
                      SizedBox(width: 7),
                      Text('HASANI WORKHUB  ·  2026',
                          style: TextStyle(
                              color: Color(0xFFDDE5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Everything your team needs,\nin one beautiful place.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 45,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2),
                ),
                const SizedBox(height: 15),
                const Text(
                  'A smarter workspace for attendance, payroll, rosters and requests—securely connected for every Hasani Books team.',
                  style: TextStyle(
                      color: Color(0xFFC8D3F1), fontSize: 15, height: 1.55),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .16)),
                  ),
                  child: const Row(
                    children: [
                      _HeroMetric(Icons.schedule_rounded, 'Attendance', 'Live'),
                      _HeroDivider(),
                      _HeroMetric(Icons.payments_outlined, 'Payroll', 'Simple'),
                      _HeroDivider(),
                      _HeroMetric(Icons.shield_outlined, 'Security', 'Private'),
                    ],
                  ),
                ),
                const SizedBox(height: 23),
                const Wrap(spacing: 10, runSpacing: 10, children: [
                  _LoginFeature(Icons.verified_user_outlined, 'Protected'),
                  _LoginFeature(Icons.bolt_outlined, 'Fast access'),
                  _LoginFeature(Icons.devices_outlined, 'Any device'),
                ]),
                const Spacer(),
                const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: Colors.white38, size: 14),
                    SizedBox(width: 6),
                    Text('Secure employee access',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
  Widget _loginCard({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 22 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF1F5FF)],
        ),
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        border: Border.all(
          color: const Color(0xFFD5DEFF),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF5273EA), Color(0xFF263FA8)]),
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x443B5ED7),
                      blurRadius: 20,
                      offset: Offset(0, 8))
                ],
              ),
              child: const Icon(Icons.lock_person_rounded,
                  color: Colors.white, size: 27),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Welcome to Workhub',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: Color(0xFF263451),
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Center(
            child: Text(
              'Sign in securely to continue to Hasani Workhub.',
              style: TextStyle(
                color: Color(0xFF687083),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !loading,
            decoration: _inputDecoration(
              'Username / Employee ID',
              Icons.person_outline,
            ),
            onSubmitted: (_) {
              FocusScope.of(context).nextFocus();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !loading,
            onSubmitted: (_) {
              if (!loading) {
                _login();
              }
            },
            decoration: _inputDecoration(
              'Password',
              Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
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
                ),
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFCDD2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3157D5),
                foregroundColor: const Color(0xFFF3F5F8),
                disabledBackgroundColor: const Color(0xFFB8B8B8),
                elevation: 4,
                shadowColor: const Color(0x55C89A45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: Color(0xFF8B6F7A),
                  ),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'ENTER YOUR WORKSPACE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 28),
          _loginInformation(),
        ],
      ),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _logo() {
    return Center(
      child: Container(
        width: 270,
        height: 112,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF8B6F7A),
            width: 1.4,
          ),
        ),
        child: Image.asset(
          'assets/hasani_books_logo.jpg',
          fit: BoxFit.contain,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF1F5FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'HASANI BOOKS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF263451),
                  letterSpacing: 1,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN INFORMATION
  // ============================================================

  Widget _loginInformation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD5DEFF),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branch Login',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Use your configured branch username and password.',
          ),
          SizedBox(height: 12),
          Text(
            'Employee Login',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'For your first login, replace the default password before opening your dashboard.',
          ),
          SizedBox(height: 12),
          Text(
            'Administrator Login',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Use your configured administrator credentials.',
          ),
        ],
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
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFFFFDF8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD8CCB7),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD8CCB7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF8B6F7A),
          width: 2,
        ),
      ),
    );
  }
}

class _LoginFeature extends StatelessWidget {
  const _LoginFeature(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: const Color(0xFFBFD0FF)),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFFD27D), size: 20),
            const SizedBox(height: 7),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Color(0xFFAEBCE2), fontSize: 10)),
          ],
        ),
      );
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 38,
        color: Colors.white.withValues(alpha: .14),
      );
}
