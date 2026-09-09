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
  await SupabaseService.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  await AppService.instance.restore();
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
          seedColor: const Color(0xFF24143D),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF24143D),
          onPrimary: const Color(0xFFFFFBF2),
          primaryContainer: const Color(0xFFECE3F5),
          secondary: const Color(0xFFB98A3D),
          onSecondary: const Color(0xFF201508),
          secondaryContainer: const Color(0xFFF4E5C5),
          tertiary: const Color(0xFF643B6F),
          surface: const Color(0xFFFFFBF5),
          onSurface: const Color(0xFF211A29),
          outline: const Color(0xFFB9ADB9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F0F4),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF3B3141), height: 1.45),
          bodyMedium: TextStyle(color: Color(0xFF665B68), height: 1.4),
          titleLarge: TextStyle(
            color: Color(0xFF24143D),
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF24143D),
            fontWeight: FontWeight.w700,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A102B),
          foregroundColor: Color(0xFFFFFBF2),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shadowColor: const Color(0x1F24143D),
          color: const Color(0xFFFFFBF5),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2D5C5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCF8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8CDD9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8CDD9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFB98A3D),
              width: 2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF24143D),
            foregroundColor: const Color(0xFFFFFBF2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFB98A3D)),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF24143D),
            foregroundColor: const Color(0xFFFFFBF2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFB98A3D)),
            ),
          ),
        ),
      ),
      home: _homePage(),
    );
  }
}
