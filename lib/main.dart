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
          seedColor: const Color(0xFF263451),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF263451),
          onPrimary: const Color(0xFFF7F3EA),
          secondary: const Color(0xFFB68A3A),
          onSecondary: const Color(0xFF263451),
          surface: const Color(0xFFF7F3EA),
          onSurface: const Color(0xFF263451),
          outline: const Color(0xFFC9C0AD),
        ),
        scaffoldBackgroundColor: const Color(0xFFE9E5DC),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF34415B)),
          bodyMedium: TextStyle(color: Color(0xFF5D6677)),
          titleLarge: TextStyle(
            color: Color(0xFF263451),
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF263451),
            fontWeight: FontWeight.w700,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF263451),
          foregroundColor: Color(0xFFF7F3EA),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFF7F3EA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD4CBB9)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFBF8F1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC9C0AD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC9C0AD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFB68A3A),
              width: 2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF263451),
            foregroundColor: const Color(0xFFF7F3EA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFB68A3A)),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF263451),
            foregroundColor: const Color(0xFFF7F3EA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFB68A3A)),
            ),
          ),
        ),
      ),
      home: _homePage(),
    );
  }
}
