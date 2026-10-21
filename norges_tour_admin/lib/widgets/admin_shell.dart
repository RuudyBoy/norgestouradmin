import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:norges_tour_admin/pages/dashboard/dashboard_page.dart';
import 'package:norges_tour_admin/pages/all_players_page.dart';
import 'package:norges_tour_admin/pages/player_claims_page.dart';
import 'package:norges_tour_admin/theme/app_colors.dart';
import 'package:norges_tour_admin/theme/admin_ui.dart';
import 'package:norges_tour_admin/theme/responsive_layout.dart';

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

  /// Lar sider som er lagt oppå skallet (f.eks. turneringssiden med egen
  /// sidemeny) be om å bytte hovedfane når de lukkes.
  static final ValueNotifier<int?> navRequest = ValueNotifier<int?>(null);

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
    AdminShell.navRequest.addListener(_onNavRequest);
  }

  void _onNavRequest() {
    final index = AdminShell.navRequest.value;
    if (index == null) return;
    AdminShell.navRequest.value = null;
    setIndex(index);
  }

  @override
  void dispose() {
    AdminShell.navRequest.removeListener(_onNavRequest);
    super.dispose();
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
              showLiveCounts: !widget.testMode && widget.children == null && widget.bodyBuilder == null,
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
              color: AppColors.adminSidebarBg,
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

  /// Viser teller for ventende spillerkrav (leser `player_claims` med status
  /// `pending`). Slås av i tester uten Firebase.
  final bool showLiveCounts;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.showLiveCounts = false,
  });

  Widget _claimsBadge() {
    if (!showLiveCounts) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('player_claims')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        final n = snap.hasData ? snap.data!.docs.length : 0;
        if (n == 0) return const SizedBox.shrink();
        return AdminPill.count('$n', background: AppColors.coral, foreground: AppColors.ink);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.adminSidebarBg,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.adminPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sports_volleyball,
                    color: AppColors.adminBrandIcon,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Spike Dunk',
                        style: AdminText.ui(size: 16, weight: FontWeight.w700, color: AppColors.adminSidebarText),
                      ),
                      Text(
                        'Admin · Norges Tour',
                        style: AdminText.ui(size: 12, color: AppColors.adminSidebarTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Section Label ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Text(
              'MENY',
              style: AdminText.kicker(color: AppColors.adminSidebarTextSecondary),
            ),
          ),

          // ── Navigation Destinations ───────────────────────────────
          for (final dest in AdminNavDestination.values) ...[
            if (dest.index > 0) const SizedBox(height: 4),
            _SidebarTile(
              title: dest.title,
              icon: selectedIndex == dest.index ? dest.iconFilled : dest.iconOutlined,
              isSelected: selectedIndex == dest.index,
              onTap: () => onDestinationSelected(dest.index),
              trailing: dest == AdminNavDestination.claims ? _claimsBadge() : null,
            ),
          ],

          const Spacer(),

          // ── Bottom Logout Action ──────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.adminSidebarDivider,
          ),
          _SidebarTile(
            title: 'Logg ut',
            icon: Icons.logout,
            isDestructive: true,
            isSelected: false,
            onTap: () => onDestinationSelected(3),
          ),
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
  final Widget? trailing;

  const _SidebarTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.isDestructive = false,
    required this.onTap,
    this.trailing,
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
      itemColor = _isHovered ? AppColors.adminDangerSidebarHover : AppColors.adminDangerSidebar;
      bgColor = _isHovered
          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
          : Colors.transparent;
    } else if (widget.isSelected) {
      itemColor = AppColors.adminSidebarText;
      bgColor = AppColors.adminPrimary;
    } else {
      itemColor = _isHovered ? AppColors.adminSidebarText : AppColors.adminSidebarTextSecondary;
      bgColor = _isHovered
          ? AppColors.adminSidebarText.withValues(alpha: 0.1)
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
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: itemColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: AdminText.ui(
                    size: 15,
                    color: itemColor,
                    weight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
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
      backgroundColor: AppColors.adminSidebarBg,
      shape: const RoundedRectangleBorder(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ───────────────────────────────────────────────
          DrawerHeader(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(
              color: Colors.transparent,
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
                    color: AppColors.adminPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sports_volleyball,
                    color: AppColors.adminBrandIcon,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Spike Dunk Admin',
                  style: TextStyle(
                    color: AppColors.adminSidebarText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Kontrollpanel',
                  style: TextStyle(
                    color: AppColors.adminSidebarTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Turneringer · Spillerdatabase · Spillerkrav ───────────
          for (final dest in AdminNavDestination.values)
            ListTile(
              leading: Icon(
                selectedIndex == dest.index ? dest.iconFilled : dest.iconOutlined,
                color: selectedIndex == dest.index
                    ? AppColors.adminSidebarText
                    : AppColors.adminSidebarTextSecondary,
              ),
              title: Text(
                dest.title,
                style: TextStyle(
                  color: AppColors.adminSidebarText,
                  fontWeight: selectedIndex == dest.index ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: selectedIndex == dest.index,
              selectedTileColor: AppColors.adminPrimary,
              onTap: () => _handleNavigation(context, dest.index),
            ),

          const Divider(color: AppColors.adminSidebarDivider),

          // ── Logg ut ───────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.adminDangerSidebar),
            title: const Text(
              'Logg ut',
              style: TextStyle(
                color: AppColors.adminDangerSidebar,
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
