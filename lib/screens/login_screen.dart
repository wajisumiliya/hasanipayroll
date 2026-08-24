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

      if (result != null &&
          result != 'FIRST_LOGIN_OTP_REQUIRED') {
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
      // must verify OTP and create a new password.
      // ==========================================================

      if (result == 'FIRST_LOGIN_OTP_REQUIRED') {
        setState(() {
          loading = false;
        });

        await _showFirstLoginOtpDialog();

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

        errorMessage =
        'Unable to connect to the payroll server. '
            'Please check your connection and try again.';
      });
    }
  }

  // ============================================================
  // FIRST LOGIN OTP
  // ============================================================

  Future<void> _showFirstLoginOtpDialog() async {
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool requestingOtp = false;
    bool verifyingOtp = false;
    bool savingPassword = false;
    bool otpSent = false;
    bool otpVerified = false;

    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> requestOtp() async {
              setDialogState(() {
                requestingOtp = true;
                dialogError = null;
              });

              final result =
              await service.requestFirstLoginOtp();

              if (!mounted) return;

              setDialogState(() {
                requestingOtp = false;

                if (result == null) {
                  otpSent = true;
                } else {
                  dialogError = result;
                }
              });
            }

            Future<void> verifyOtp() async {
              final otp = otpController.text.trim();

              if (otp.length != 6) {
                setDialogState(() {
                  dialogError =
                  'Please enter the 6-digit OTP.';
                });

                return;
              }

              setDialogState(() {
                verifyingOtp = true;
                dialogError = null;
              });

              final result =
              await service.verifyFirstLoginOtp(
                otp,
              );

              if (!mounted) return;

              setDialogState(() {
                verifyingOtp = false;

                if (result == null) {
                  otpVerified = true;
                } else {
                  dialogError = result;
                }
              });
            }

            Future<void> savePassword() async {
              final newPassword =
                  newPasswordController.text;

              final confirmPassword =
                  confirmPasswordController.text;

              if (newPassword.length < 6) {
                setDialogState(() {
                  dialogError =
                  'Password must contain at least 6 characters.';
                });

                return;
              }

              if (newPassword != confirmPassword) {
                setDialogState(() {
                  dialogError =
                  'Passwords do not match.';
                });

                return;
              }

              setDialogState(() {
                savingPassword = true;
                dialogError = null;
              });

              final result =
              await service.completeFirstLogin(
                newPassword,
              );

              if (!mounted) return;

              if (result != null) {
                setDialogState(() {
                  savingPassword = false;
                  dialogError = result;
                });

                return;
              }

              Navigator.of(dialogContext).pop();

              final user = service.currentUser;

              if (user != null) {
                _openCorrectPortal(user);
              }
            }

            return AlertDialog(
              title: Text(
                !otpSent
                    ? 'First Login Verification'
                    : !otpVerified
                    ? 'Verify OTP'
                    : 'Create New Password',
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      if (!otpSent) ...[
                        const Text(
                          'For security, you must verify your registered email address before creating your new password.',
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: requestingOtp
                                ? null
                                : requestOtp,
                            child: requestingOtp
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'SEND OTP',
                            ),
                          ),
                        ),
                      ],

                      if (otpSent && !otpVerified) ...[
                        const Text(
                          'Enter the 6-digit OTP sent to your registered email address.',
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: otpController,
                          keyboardType:
                          TextInputType.number,
                          maxLength: 6,
                          decoration: _inputDecoration(
                            '6-Digit OTP',
                            Icons.lock_outline,
                          ),
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: verifyingOtp
                                ? null
                                : verifyOtp,
                            child: verifyingOtp
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'VERIFY OTP',
                            ),
                          ),
                        ),

                        TextButton(
                          onPressed: requestingOtp
                              ? null
                              : requestOtp,
                          child: const Text(
                            'Resend OTP',
                          ),
                        ),
                      ],

                      if (otpVerified) ...[
                        const Text(
                          'OTP verified successfully. Please create your new password.',
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller:
                          newPasswordController,
                          obscureText: true,
                          decoration: _inputDecoration(
                            'New Password',
                            Icons.lock_outline,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller:
                          confirmPasswordController,
                          obscureText: true,
                          decoration: _inputDecoration(
                            'Confirm New Password',
                            Icons.lock_outline,
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: savingPassword
                                ? null
                                : savePassword,
                            child: savingPassword
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'SAVE NEW PASSWORD',
                            ),
                          ),
                        ),
                      ],

                      if (dialogError != null) ...[
                        const SizedBox(height: 16),

                        Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                  requestingOtp ||
                      verifyingOtp ||
                      savingPassword
                      ? null
                      : () {
                    service.cancelFirstLoginOtp();

                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    'CANCEL',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    otpController.dispose();
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

      errorMessage =
      'Your account does not have a valid portal role.';
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
      backgroundColor:
      const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
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
      padding:
      const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.07,
            ),
            blurRadius: 30,
            offset:
            const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _logo(),

          const SizedBox(height: 30),

          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 28,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF172033),
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
            controller:
            usernameController,
            textInputAction:
            TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !loading,
            decoration:
            _inputDecoration(
              'Username / Employee ID',
              Icons.person_outline,
            ),
            onSubmitted: (_) {
              FocusScope.of(context)
                  .nextFocus();
            },
          ),

          const SizedBox(height: 16),

          TextField(
            controller:
            passwordController,
            obscureText:
            obscurePassword,
            textInputAction:
            TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !loading,
            onSubmitted: (_) {
              if (!loading) {
                _login();
              }
            },
            decoration:
            _inputDecoration(
              'Password',
              Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: loading
                    ? null
                    : () {
                  setState(() {
                    obscurePassword =
                    !obscurePassword;
                  });
                },
                icon: Icon(
                  obscurePassword
                      ? Icons
                      .visibility_outlined
                      : Icons
                      .visibility_off_outlined,
                ),
              ),
            ),
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                const Color(0xFFFFEBEE),
                borderRadius:
                BorderRadius.circular(10),
                border: Border.all(
                  color:
                  const Color(0xFFFFCDD2),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      errorMessage!,
                      style:
                      const TextStyle(
                        color: Colors.red,
                        fontWeight:
                        FontWeight.w600,
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
              onPressed:
              loading ? null : _login,
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFF15965D),
                foregroundColor:
                Colors.white,
                disabledBackgroundColor:
                Colors.grey.shade300,
                elevation: 0,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(10),
                ),
              ),
              child: loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'LOGIN',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
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
              alignment:
              Alignment.center,
              decoration: BoxDecoration(
                color:
                const Color(0xFFF5F7FB),
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: const Text(
                'HASANI BOOKS',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight:
                  FontWeight.w900,
                  color:
                  Color(0xFF2D55D8),
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
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
        const Color(0xFFF5F7FB),
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: const Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Branch Login',
            style: TextStyle(
              fontWeight:
              FontWeight.bold,
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
              fontWeight:
              FontWeight.bold,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'For your first login, verify the OTP sent to your registered email and create a new password.',
          ),

          SizedBox(height: 12),

          Text(
            'Administrator Login',
            style: TextStyle(
              fontWeight:
              FontWeight.bold,
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
      fillColor:
      const Color(0xFFF8F9FC),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(10),
        borderSide:
        const BorderSide(
          color: Colors.black12,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(10),
        borderSide:
        const BorderSide(
          color: Colors.black12,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(10),
        borderSide:
        const BorderSide(
          color: Color(0xFF15965D),
          width: 2,
        ),
      ),
    );
  }
}