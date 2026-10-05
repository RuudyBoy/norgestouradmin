import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'all_players_page.dart';
import 'player_claims_page.dart';
import 'theme/app_colors.dart';
import 'theme/responsive_layout.dart';

/// Top-level navigation items supported by the Spike Dunk Admin Shell.
enum AdminNavDestination {
  tournaments(
    title: 'Turneringer',
    iconOutlined: Icons.emoji_events_outlined,
    iconFilled: Icons.emoji_events,
  ),
  players(
    title: 'Spillerdatabase',
    iconOutlined: Icons.people_outline,
    iconFilled: Icons.people,
  ),
  claims(
    title: 'Spillerkrav',
    iconOutlined: Icons.assignment_ind_outlined,
    iconFilled: Icons.assignment_ind,
  );

  const AdminNavDestination({
    required this.title,
    required this.iconOutlined,
    required this.iconFilled,
  });

  final String title;
  final IconData iconOutlined;
  final IconData iconFilled;
}

/// Unified adaptive shell for Spike Dunk Admin.
///
/// Provides:
/// - Desktop (width >= 1000px): Permanent left sidebar with branding, navigation items, and logout.
/// - Mobile / Tablet (width < 1000px): Clean pass-through to the active screen which renders
///   a standard AppBar with a hamburger menu opening [AdminDrawer].
/// - Zero disruption to detail navigation: detail pages pushed via [Navigator.push]
///   open over the shell with standard back button support.
class AdminShell extends StatefulWidget {
  /// The destination index to display initially (0 = Tournaments, 1 = Players, 2 = Claims).
  final int initialIndex;

  /// Optional test mode for headless testing without Firebase dependencies.
  final bool testMode;

  /// Optional custom page builder for tests.
  final Widget Function(BuildContext context, int index)? bodyBuilder;

  /// Optional explicit child widgets for testing or custom host scenarios.
  final List<Widget>? children;

  const AdminShell({
    super.key,
    this.initialIndex = 0,
    this.testMode = false,
    this.bodyBuilder,
    this.children,
  });

  /// Access the nearest [AdminShellState] to programmatically change tabs.
  static AdminShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<AdminShellState>();

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
  late int _selectedIndex;
  final Set<int> _loadedIndices = <int>{};
  final _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadedIndices.add(_selectedIndex);
  }

  /// Sets the currently active top-level destination index.
  void setIndex(int index) {
    if (index >= 0 && index <= 2 && index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
        _loadedIndices.add(index);
      });
    }
  }

  Widget _buildCurrentPage() {
    if (widget.children != null) {
      return IndexedStack(
        key: _stackKey,
        index: _selectedIndex,
        children: widget.children!,
      );
    }
    if (widget.bodyBuilder != null) {
      return widget.bodyBuilder!(context, _selectedIndex);
    }
    if (widget.testMode) {
      return IndexedStack(
        key: _stackKey,
        index: _selectedIndex,
        children: const [
          Center(child: Text('Test Destination 0')),
          Center(child: Text('Test Destination 1')),
          Center(child: Text('Test Destination 2')),
        ],
      );
    }
    return IndexedStack(
      key: _stackKey,
      index: _selectedIndex,
      children: [
        _loadedIndices.contains(0) ? const AdminDashboard() : const SizedBox.shrink(),
        _loadedIndices.contains(1) ? const AllPlayersPage() : const SizedBox.shrink(),
        _loadedIndices.contains(2) ? const PlayerClaimsPage() : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktopOrLarger(context);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.adminBg,
        body: Row(
          children: [
            // Permanent desktop navigation sidebar
            AdminSidebar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index == 3) {
                  // Logg ut
                  FirebaseAuth.instance.signOut();
                } else {
                  setIndex(index);
                }
              },
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0x1AFFFFFF),
            ),
            // Active page content
            Expanded(
              child: _buildCurrentPage(),
            ),
          ],
        ),
      );
    }

    // On mobile / tablet, render the active page directly.
    // The active page renders its own AppBar with hamburger icon opening AdminDrawer.
    return _buildCurrentPage();
  }
}

/// Permanent left sidebar navigation widget for desktop screens (width >= 1000px).
class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.adminSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.adminOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.adminOrange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.sports_volleyball,
                    color: AppColors.adminOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Spike Dunk',
                        style: TextStyle(
                          color: AppColors.adminText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Kontrollpanel',
                        style: TextStyle(
                          color: AppColors.adminTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Color(0x1AFFFFFF),
              height: 1,
              thickness: 1,
            ),
          ),

          const SizedBox(height: 16),

          // ── Section Label ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              'MENY',
              style: TextStyle(
                color: AppColors.adminTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // ── Navigation Destinations ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _SidebarTile(
                  title: AdminNavDestination.tournaments.title,
                  icon: selectedIndex == 0
                      ? AdminNavDestination.tournaments.iconFilled
                      : AdminNavDestination.tournaments.iconOutlined,
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                const SizedBox(height: 4),
                _SidebarTile(
                  title: AdminNavDestination.players.title,
                  icon: selectedIndex == 1
                      ? AdminNavDestination.players.iconFilled
                      : AdminNavDestination.players.iconOutlined,
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                const SizedBox(height: 4),
                _SidebarTile(
                  title: AdminNavDestination.claims.title,
                  icon: selectedIndex == 2
                      ? AdminNavDestination.claims.iconFilled
                      : AdminNavDestination.claims.iconOutlined,
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Bottom Logout Action ──────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Color(0x1AFFFFFF),
              height: 1,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _SidebarTile(
              title: 'Logg ut',
              icon: Icons.logout,
              isDestructive: true,
              isSelected: false,
              onTap: () => onDestinationSelected(3),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Single interactive destination tile in the [AdminSidebar].
class _SidebarTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color itemColor;
    final Color bgColor;

    if (widget.isDestructive) {
      itemColor = _isHovered ? const Color(0xFFF87171) : const Color(0xFFEF4444);
      bgColor = _isHovered
          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
          : Colors.transparent;
    } else if (widget.isSelected) {
      itemColor = AppColors.adminOrange;
      bgColor = AppColors.adminOrange.withValues(alpha: 0.15);
    } else {
      itemColor = _isHovered ? AppColors.adminText : AppColors.adminTextSecondary;
      bgColor = _isHovered
          ? AppColors.adminSurfaceElevated
          : Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: widget.isSelected
                ? Border.all(
                    color: AppColors.adminOrange.withValues(alpha: 0.3),
                    width: 1,
                  )
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: itemColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified mobile drawer widget used on screens with viewport width < 1000px.
class AdminDrawer extends StatelessWidget {
  /// The index of the active destination (0 = Tournaments, 1 = Players, 2 = Claims).
  final int selectedIndex;

  const AdminDrawer({
    super.key,
    this.selectedIndex = 0,
  });

  void _handleNavigation(BuildContext context, int destinationIndex) {
    // 1. Look up ancestor AdminShellState BEFORE popping the drawer route.
    // Calling Navigator.pop first deactivates the drawer element tree,
    // causing an unsafe ancestor lookup assertion error.
    final shellState = AdminShell.of(context);
    Navigator.pop(context); // Close mobile drawer

    if (shellState != null) {
      shellState.setIndex(destinationIndex);
    } else {
      // Fallback navigation when the page is rendered outside AdminShell
      if (destinationIndex == selectedIndex) return;
      if (!context.mounted) return;
      switch (destinationIndex) {
        case 0:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
          break;
        case 1:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AllPlayersPage()),
          );
          break;
        case 2:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PlayerClaimsPage()),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.adminSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ───────────────────────────────────────────────
          DrawerHeader(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(
              color: AppColors.adminSurfaceElevated,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.adminOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sports_volleyball,
                    color: AppColors.adminOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Spike Dunk Admin',
                  style: TextStyle(
                    color: AppColors.adminText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Kontrollpanel',
                  style: TextStyle(
                    color: AppColors.adminTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Turneringer ───────────────────────────────────────────
          ListTile(
            leading: Icon(
              selectedIndex == 0
                  ? AdminNavDestination.tournaments.iconFilled
                  : AdminNavDestination.tournaments.iconOutlined,
              color: selectedIndex == 0
                  ? AppColors.adminOrange
                  : AppColors.adminTextSecondary,
            ),
            title: Text(
              AdminNavDestination.tournaments.title,
              style: TextStyle(
                color: selectedIndex == 0
                    ? AppColors.adminOrange
                    : AppColors.adminText,
                fontWeight: selectedIndex == 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            selected: selectedIndex == 0,
            selectedTileColor: AppColors.adminOrange.withValues(alpha: 0.12),
            onTap: () => _handleNavigation(context, 0),
          ),

          // ── Spillerdatabase ───────────────────────────────────────
          ListTile(
            leading: Icon(
              selectedIndex == 1
                  ? AdminNavDestination.players.iconFilled
                  : AdminNavDestination.players.iconOutlined,
              color: selectedIndex == 1
                  ? AppColors.adminOrange
                  : AppColors.adminTextSecondary,
            ),
            title: Text(
              AdminNavDestination.players.title,
              style: TextStyle(
                color: selectedIndex == 1
                    ? AppColors.adminOrange
                    : AppColors.adminText,
                fontWeight: selectedIndex == 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            selected: selectedIndex == 1,
            selectedTileColor: AppColors.adminOrange.withValues(alpha: 0.12),
            onTap: () => _handleNavigation(context, 1),
          ),

          // ── Spillerkrav ───────────────────────────────────────────
          ListTile(
            leading: Icon(
              selectedIndex == 2
                  ? AdminNavDestination.claims.iconFilled
                  : AdminNavDestination.claims.iconOutlined,
              color: selectedIndex == 2
                  ? AppColors.adminOrange
                  : AppColors.adminTextSecondary,
            ),
            title: Text(
              AdminNavDestination.claims.title,
              style: TextStyle(
                color: selectedIndex == 2
                    ? AppColors.adminOrange
                    : AppColors.adminText,
                fontWeight: selectedIndex == 2
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            selected: selectedIndex == 2,
            selectedTileColor: AppColors.adminOrange.withValues(alpha: 0.12),
            onTap: () => _handleNavigation(context, 2),
          ),

          const Divider(color: Color(0x1AFFFFFF)),

          // ── Logg ut ───────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            title: const Text(
              'Logg ut',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
