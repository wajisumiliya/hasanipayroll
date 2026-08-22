import 'package:flutter/material.dart';

import '../services/app_service.dart';
import 'admin_dashboard.dart';
import 'branch_dashboard.dart';
import 'employee_portal.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AppService service = AppService.instance;

  final TextEditingController usernameController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      await service.restore();

      if (!mounted) {
        return;
      }

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
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // LOGIN
  // ==========================================================================

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

    if (loading) {
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      /*
       * IMPORTANT
       *
       * This method must authenticate through Supabase Auth.
       *
       * It should NOT:
       *
       *   - download passwords
       *   - compare plaintext passwords
       *   - authenticate only from the app_user table
       *
       * AppService.loginWithSupabaseAuth() should:
       *
       *   1. Authenticate the user with Supabase Auth.
       *   2. Obtain the authenticated auth.uid().
       *   3. Load the user's profile/role.
       *   4. Set AppService.currentUser.
       */

      final error = await service.loginWithSupabaseAuth(
        username,
        password,
      );

      if (!mounted) {
        return;
      }

      if (error != null) {
        setState(() {
          loading = false;
          errorMessage = error;
        });
        return;
      }

      final user = service.currentUser;

      if (user == null) {
        setState(() {
          loading = false;
          errorMessage =
              'Login succeeded, but your account profile could not be found.';
        });
        return;
      }

      setState(() {
        loading = false;
      });

      _openCorrectPortal(user);
    } catch (e) {
      debugPrint('Login error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        errorMessage =
            'Unable to sign in. Please check your credentials and try again.';
      });
    }
  }

  // ==========================================================================
  // PORTAL ROUTING
  // ==========================================================================

  void _openCorrectPortal(dynamic user) {
    if (!mounted) {
      return;
    }

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
      errorMessage =
          'Your account does not have a valid portal role.';
    });
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      errorMessage = message;
    });
  }

  // ==========================================================================
  // UI
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: _loginCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _logo(),

          const SizedBox(height: 30),

          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Sign in securely to continue to the payroll portal.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 28),

          TextField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
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
                backgroundColor: const Color(0xFF15965D),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                      'LOGIN',
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

  // ==========================================================================
  // LOGO
  // ==========================================================================

  Widget _logo() {
    return Center(
      child: SizedBox(
        width: 230,
        height: 100,
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
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'HASANI BOOKS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D55D8),
                  letterSpacing: 1,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // LOGIN INFORMATION
  // ==========================================================================

  Widget _loginInformation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(10),
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
            'Use your Employee ID and employee password.',
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

  // ==========================================================================
  // INPUT DECORATION
  // ==========================================================================

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.black12,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.black12,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFF15965D),
          width: 2,
        ),
      ),
    );
  }
}
