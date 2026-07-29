import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/providers.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/onboarding/login_screen.dart';
import '../features/onboarding/registration_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/daily_record/daily_record_screen.dart';
import '../features/history/history_screen.dart';
import '../features/orientation/orientation_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/article_detail_screen.dart';
import '../features/faq/faq_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/profile/profile_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isOnAuthRoute = state.matchedLocation == '/splash' ||
        state.matchedLocation == '/welcome' ||
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (user == null && !isOnAuthRoute) {
      return '/welcome';
    }
    if (user != null && isOnAuthRoute) {
      return '/dashboard';
    }
    return null;
  },
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegistrationScreen()),

    ShellRoute(
      builder: (_, _, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
        GoRoute(path: '/orientation', builder: (_, _) => const OrientationScreen()),
        GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
        GoRoute(path: '/faq', builder: (_, _) => const FAQScreen()),
        GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: '/record', builder: (_, _) => const DailyRecordScreen()),
        GoRoute(
          path: '/record/edit/:id',
          builder: (_, state) => DailyRecordScreen(
            recordId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: '/history',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return HistoryScreen(
              filterDate: extra?['filterDate'] as DateTime?,
              origin: extra?['origin'] as String?,
            );
          },
        ),
      ],
    ),

    GoRoute(
      path: '/library/:id',
      builder: (_, state) => ArticleDetailScreen(
        id: state.pathParameters['id']!,
      ),
    ),
  ],
);

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  static const _routeToIndex = <String, int>{
    '/dashboard': 0,
    '/orientation': 1,
    '/library': 2,
    '/faq': 2,
    '/profile': 3,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    int? index = _routeToIndex[location];
    // Handle dynamic routes like /record/edit/:id
    if (index == null && location.startsWith('/record/edit')) {
      index = 0;
    }
    if (index != null && index != _selectedIndex) {
      _selectedIndex = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de conectividad y mostrar SnackBar auto-dismiss
    ref.listen(isConnectedProvider,
        (AsyncValue<bool>? previous, AsyncValue<bool> next) {
      // Saltar la primera emisión o si no está resuelto
      final prevValue = previous?.value;
      final nextValue = next.value;
      if (prevValue == null || nextValue == null) return;

      if (!nextValue) {
        // Transición: online → offline
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin conexión — los datos se sincronizarán cuando vuelva internet',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.alertYellow.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        // Transición: offline → online
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conexión restablecida',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.alertGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          Expanded(child: widget.child),
        ],
      ),
      // Sin floatingActionButton — el botón central vive DENTRO de la barra
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Bottom nav completa ──
  Widget _buildBottomNav(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: AppColors.goldPrimary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldMid.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Fila de items alineados al fondo ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _buildNavItem(0, Icons.home_outlined, Icons.home, 'Inicio')),
                    Expanded(child: _buildNavItem(1, Icons.forum_outlined, Icons.forum, 'Chat')),
                    const SizedBox(width: 68),
                    Expanded(child: _buildNavItem(2, Icons.videocam_outlined, Icons.videocam, 'Educativo')),
                    Expanded(child: _buildNavItem(3, Icons.person_outline, Icons.person, 'Perfil')),
                  ],
                ),
              ),
            ),

            // ── Botón central elevado — label alineado con los otros ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // El círculo se eleva con un offset negativo
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: GestureDetector(
                      onTap: () => context.push('/record'),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.warmWhite,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldMid.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.goldMid, AppColors.goldDark],
                            ),
                          ),
                          child: const Icon(
                            Icons.show_chart,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Label "Registro" — misma posición que los otros labels
                  Text(
                    'Registro',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Item: fondo activo redondeado ──
  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    final route = ['/dashboard', '/orientation', '/library', '/profile'][index];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        context.go(route);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF0C2) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected ? AppColors.goldDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.goldDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
