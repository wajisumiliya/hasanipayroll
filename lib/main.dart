import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/admin_dashboard.dart';
import 'screens/branch_dashboard.dart';
import 'screens/employee_portal.dart';
import 'screens/login_screen.dart';
import 'screens/request_admin_dashboard.dart';
import 'screens/supabase_service.dart';
import 'services/app_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppService.instance.restore();
  await NotificationService.initialize(
    employeeId: AppService.instance.currentEmployeeId,
    branchId: AppService.instance.currentBranchId,
  );
  runApp(const HasaniPayrollApp());
}

class HasaniPayrollApp extends StatelessWidget {
  const HasaniPayrollApp({super.key});

  Widget _homePage() {
    final user = AppService.instance.currentUser;
    if (user?.isAdmin == true && user?.staffScope == 'requests') {
      return const RequestAdminDashboard();
    }
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
          seedColor: const Color(0xFF08255F),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF08255F),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDCE8F8),
          secondary: const Color(0xFF315E8F),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE4ECF5),
          tertiary: const Color(0xFF163F70),
          surface: const Color(0xFFF9FBFE),
          onSurface: const Color(0xFF12213A),
          outline: const Color(0xFFA8B5C7),
        ),
        scaffoldBackgroundColor: const Color(0xFFEFF3F8),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF263750), height: 1.45),
          bodyMedium: TextStyle(color: Color(0xFF5C6D83), height: 1.4),
          titleLarge: TextStyle(
            color: Color(0xFF08255F),
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF08255F),
            fontWeight: FontWeight.w700,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF08255F),
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: Color(0x5508255F),
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 7,
          shadowColor: const Color(0x3308255F),
          color: const Color(0xFFF9FBFE),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFD7E0EC)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFCFDFF),
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
              color: Color(0xFF315E8F),
              width: 2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF08255F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF315E8F)),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF08255F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF315E8F)),
            ),
          ),
        ),
      ),
      home: _homePage(),
    );
  }
}
