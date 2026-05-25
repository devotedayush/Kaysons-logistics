import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/onboarding_welcome_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_email_screen.dart';
import '../../features/auth/register_password_screen.dart';
import '../../features/auth/register_name_screen.dart';
import '../../features/auth/register_bank_screen.dart';
import '../../features/auth/register_contact_screen.dart';
import '../../features/transporter/bid_detail_screen.dart';
import '../../features/transporter/afterbid_screen.dart';
import '../../features/transporter/drivers_screen.dart';
import '../../features/transporter/profile_screen.dart';
import '../../features/transporter/transporter_shell.dart';
import '../../features/transporter/vehicles_screen.dart';
import '../../features/logistics_manager/bid_setup_screen.dart';
import '../../features/logistics_manager/bid_management_screen.dart';
import '../../features/logistics_manager/bid_edit_screen.dart';
import '../../features/logistics_manager/invoice_link_screen.dart';
import '../../features/logistics_manager/lm_shell.dart';
import '../../features/logistics_manager/lm_profile_screen.dart';
import '../../features/logistics_manager/lm_track_screen.dart';
import '../../features/dispatch_manager/dispatch_shell.dart';
import '../../features/admin/accountant_shell.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_profile_screen.dart';
import '../../features/admin/analytics_screen.dart';
import '../../features/admin/notifications_screen.dart';
import '../supabase/auth_service.dart';
import '../supabase/supabase_bootstrap.dart';
import '../widgets/desktop_role_shell.dart';

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
  late final dynamic _sub;
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthNotifier();

const _publicPaths = {
  '/',
  '/welcome',
  '/login',
  '/register',
  '/register/password',
  '/register/name',
  '/register/bank',
  '/register/contact',
};

Widget _desktopShell({
  required AppRole role,
  required Widget child,
  int? currentIndex,
  double maxContentWidth = 1120,
}) {
  return DesktopRoleShell(
    role: role,
    currentIndex: currentIndex,
    maxContentWidth: maxContentWidth,
    child: child,
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) async {
    final loggedIn = AuthService.instance.session != null;
    final path = state.matchedLocation;
    // Splash handles its own redirect based on role; leave it alone.
    if (path == '/') return null;
    final isPublic = _publicPaths.contains(path);
    if (!loggedIn && !isPublic) return '/login';
    if (!loggedIn || isPublic) return null;
    final role = await AuthService.instance.fetchRole();
    final allowed = switch (role) {
      AppRole.admin => path.startsWith('/admin'),
      AppRole.logisticsManager => path.startsWith('/lm'),
      AppRole.dispatchManager => path.startsWith('/dm'),
      AppRole.accountant => path.startsWith('/acct'),
      AppRole.transporter =>
        path == '/home' ||
            path == '/bids' ||
            path == '/fleet' ||
            path == '/vehicles' ||
            path == '/drivers' ||
            path == '/profile' ||
            path.startsWith('/bid/'),
    };
    if (!allowed) return routeForRole(role);
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(
      path: '/welcome',
      builder: (_, __) => const OnboardingWelcomeScreen(),
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterEmailScreen()),
    GoRoute(
      path: '/register/password',
      builder: (_, __) => const RegisterPasswordScreen(),
    ),
    GoRoute(
      path: '/register/name',
      builder: (_, __) => const RegisterNameScreen(),
    ),
    GoRoute(
      path: '/register/bank',
      builder: (_, __) => const RegisterBankScreen(),
    ),
    GoRoute(
      path: '/register/contact',
      builder: (_, __) => const RegisterContactScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const TransporterShell(initialIndex: 0),
    ),
    GoRoute(
      path: '/bids',
      builder: (_, __) => const TransporterShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/fleet',
      builder: (_, __) => const TransporterShell(initialIndex: 2),
    ),
    GoRoute(
      path: '/vehicles',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.transporter,
            currentIndex: 2,
            child: const VehiclesScreen(),
          ),
    ),
    GoRoute(
      path: '/drivers',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.transporter,
            currentIndex: 2,
            child: const DriversScreen(),
          ),
    ),
    GoRoute(
      path: '/profile',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.transporter,
            child: const TransporterProfileScreen(),
          ),
    ),
    GoRoute(
      path: '/bid/:id',
      builder:
          (_, state) => BidDetailScreen(bidId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/bid/:id/after',
      builder:
          (_, state) => _desktopShell(
            role: AppRole.transporter,
            currentIndex: 2,
            child: AfterbidScreen(bidId: state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/lm/home',
      builder: (_, __) => const LogisticsShell(initialIndex: 0),
    ),
    GoRoute(
      path: '/lm/bids',
      builder: (_, __) => const LogisticsShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/lm/fleet',
      builder: (_, __) => const LogisticsShell(initialIndex: 2),
    ),
    GoRoute(
      path: '/lm/ledger',
      builder: (_, __) => const LogisticsShell(initialIndex: 3),
    ),
    GoRoute(
      path: '/lm/dispatch',
      builder: (_, __) => const LogisticsShell(initialIndex: 4),
    ),
    GoRoute(
      path: '/lm/profile',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.logisticsManager,
            child: const LmProfileScreen(),
          ),
    ),
    GoRoute(
      path: '/lm/notifications',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.logisticsManager,
            currentIndex: 0,
            child: const NotificationsScreen(),
          ),
    ),
    GoRoute(
      path: '/lm/track/:id',
      builder:
          (_, state) => _desktopShell(
            role: AppRole.logisticsManager,
            currentIndex: 2,
            child: LmTrackScreen(freightId: state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/lm/bid/new',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.logisticsManager,
            currentIndex: 1,
            child: const BidSetupScreen(),
          ),
    ),
    GoRoute(
      path: '/lm/bid/:id',
      builder:
          (_, state) => _desktopShell(
            role: AppRole.logisticsManager,
            currentIndex: 1,
            child: BidManagementScreen(bidId: state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/lm/bid/:id/edit',
      builder:
          (_, state) => _desktopShell(
            role: AppRole.logisticsManager,
            currentIndex: 1,
            child: BidEditScreen(bidId: state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/lm/bid/:id/invoice',
      builder:
          (_, state) => _desktopShell(
            role: AppRole.logisticsManager,
            currentIndex: 1,
            child: InvoiceLinkScreen(bidId: state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/dm/home',
      builder: (_, __) => const DispatchShell(initialIndex: 0),
    ),
    GoRoute(
      path: '/dm/fleet',
      builder: (_, __) => const DispatchShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/dm/profile',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.dispatchManager,
            child: const LmProfileScreen(),
          ),
    ),
    GoRoute(
      path: '/dm/track/:id',
      builder:
          (_, state) => _desktopShell(
            role: AppRole.dispatchManager,
            currentIndex: 1,
            child: LmTrackScreen(freightId: state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/acct/ledger',
      builder: (_, __) => const AccountantShell(initialIndex: 0),
    ),
    GoRoute(
      path: '/acct/analytics',
      builder: (_, __) => const AccountantShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/acct/clawd',
      builder: (_, __) => const AccountantShell(initialIndex: 2),
    ),
    GoRoute(
      path: '/acct/profile',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.accountant,
            child: const AdminProfileScreen(),
          ),
    ),
    GoRoute(
      path: '/acct/notifications',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.accountant,
            currentIndex: 0,
            child: const NotificationsScreen(),
          ),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminShell(initialIndex: 0),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (_, __) => const AdminShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/admin/bids',
      builder: (_, __) => const AdminShell(initialIndex: 2),
    ),
    GoRoute(
      path: '/admin/bid/:id',
      builder:
          (_, state) => _desktopShell(
            role: AppRole.admin,
            currentIndex: 2,
            child: BidManagementScreen(bidId: state.pathParameters['id']!),
          ),
    ),
    GoRoute(
      path: '/admin/ledger',
      builder: (_, __) => const AdminShell(initialIndex: 3),
    ),
    GoRoute(
      path: '/admin/clawd',
      builder: (_, __) => const AdminShell(initialIndex: 4),
    ),
    GoRoute(
      path: '/admin/profile',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.admin,
            child: const AdminProfileScreen(),
          ),
    ),
    GoRoute(
      path: '/admin/notifications',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.admin,
            currentIndex: 0,
            child: const NotificationsScreen(),
          ),
    ),
    GoRoute(
      path: '/admin/analytics',
      builder:
          (_, __) => _desktopShell(
            role: AppRole.admin,
            currentIndex: 0,
            child: const AnalyticsScreen(),
          ),
    ),
  ],
);
