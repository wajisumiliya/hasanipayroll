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
          seedColor: const Color(0xFF101A3A),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF101A3A),
          onPrimary: const Color(0xFFFFF8E8),
          secondary: const Color(0xFFC89A45),
          onSecondary: const Color(0xFF101A3A),
          surface: const Color(0xFFFFFCF5),
          onSurface: const Color(0xFF101A3A),
          outline: const Color(0xFFD8CCB7),
        ),

        scaffoldBackgroundColor: const Color(0xFFF4EFE2),

        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF24304F)),
          bodyMedium: TextStyle(color: Color(0xFF4E5870)),
          titleLarge: TextStyle(
            color: Color(0xFF101A3A),
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF101A3A),
            fontWeight: FontWeight.w700,
          ),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101A3A),
          foregroundColor: Color(0xFFFFF8E8),
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          color: Color(0xFFFFFCF5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(
              color: Color(0xFFE1D2B4),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFDF8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8CCB7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8CCB7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFC89A45),
              width: 2,
            ),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF101A3A),
            foregroundColor: const Color(0xFFFFF8E8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFC89A45)),
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF101A3A),
            foregroundColor: const Color(0xFFFFF8E8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFC89A45)),
            ),
          ),
        ),
      ),

      home: _homePage(),
    );
  }
}