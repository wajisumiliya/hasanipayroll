import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/admin_dashboard.dart';
import 'screens/branch_dashboard.dart';
import 'screens/employee_portal.dart';
import 'screens/login_screen.dart';
import 'screens/supabase_service.dart';
import 'services/app_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // SUPABASE INITIALIZATION
  // ============================================================

  await SupabaseService.initialize();

  // ============================================================
  // FIREBASE INITIALIZATION
  // ============================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // PUSH NOTIFICATION INITIALIZATION
  // ============================================================

  await NotificationService.initialize();

  await AppService.instance.restore();

  // ============================================================
  // START APPLICATION
  // ============================================================

  runApp(const HasaniPayrollApp());
}

class HasaniPayrollApp extends StatelessWidget {
  const HasaniPayrollApp({super.key});

  Widget _homePage() {
    final user = AppService.instance.currentUser;

    if (user?.isAdmin == true) return const AdminDashboard();
    if (user?.isBranch == true) return const BranchPortal();
    if (user?.isEmployee == true) return const EmployeePortal();
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hasani Books Payroll Portal',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D55D8),
          primary: const Color(0xFF2D55D8),
        ),

        scaffoldBackgroundColor: const Color(0xFFF5F7FB),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),

      home: _homePage(),
    );
  }
}