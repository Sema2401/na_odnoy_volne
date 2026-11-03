import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/share_screen.dart';
import 'screens/profile_screen.dart';

class AppRouter {
  static final _auth = FirebaseAuth.instance;

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthListenable(_auth),
    redirect: (context, state) {
      final isLoggedIn = _auth.currentUser != null;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _ScaffoldWithNav(state: state),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/share',
            builder: (context, state) => const ShareScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}

class _AuthListenable extends ChangeNotifier {
  final FirebaseAuth _auth;
  late final _sub = _auth.authStateChanges().listen((_) => notifyListeners());
  _AuthListenable(this._auth);

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class _ScaffoldWithNav extends StatelessWidget {
  final GoRouterState state;
  const _ScaffoldWithNav({required this.state});

  int _indexFromLocation(String location) {
    if (location.startsWith('/share')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexFromLocation(state.matchedLocation);

    return Scaffold(
      // backgroundColor прозрачный — чтобы был виден NeonBackground
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeScreen(),
          ShareScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.line, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.pink.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            const routes = ['/home', '/share', '/profile'];
            context.go(routes[i]);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              activeIcon: Icon(Icons.people, color: AppTheme.pink),
              label: 'Волна',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.graphic_eq),
              activeIcon: Icon(Icons.graphic_eq, color: AppTheme.pink),
              label: 'Поделиться',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              activeIcon: Icon(Icons.person, color: AppTheme.pink),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}