import 'package:flutter/material.dart';

/// Responsive breakpoint categories used across Norges Tour Admin.
enum ResponsiveBreakpoint {
  /// Screen width < 600px (smartphones). Single-column layouts, drawer navigation.
  mobile,

  /// Screen width 600px - 999.9px (tablets, small foldables). Intermediate padding, drawer navigation.
  tablet,

  /// Screen width 1000px - 1799.9px (standard PC monitors, laptops). Multi-column, persistent navigation sidebar.
  desktop,

  /// Screen width >= 1800px (ultrawide monitors). Centered max-width containment to prevent stretching.
  ultrawide,
}

/// Centralized responsive design tokens and layout utility methods for Norges Tour Admin.
///
/// Provides breakpoints, content max-width constraints, responsive padding queries,
/// and value selectors for adaptive UI scaling between mobile and desktop/ultrawide monitors.
abstract final class ResponsiveLayout {
  ResponsiveLayout._();

  // ── Breakpoints ────────────────────────────────────────────────────────────
  /// Mobile breakpoint threshold (< 600px).
  static const double mobileBreakpoint = 600.0;

  /// Tablet breakpoint threshold (>= 600px and < 1000px).
  static const double tabletBreakpoint = 1000.0;

  /// Ultrawide breakpoint threshold (>= 1800px).
  static const double ultrawideBreakpoint = 1800.0;

  // ── Content Max-Width Constraints ──────────────────────────────────────────
  /// Default max content width (1440px) for lists, detail pages, and general views.
  static const double defaultMaxContentWidth = 1440.0;

  /// Max content width for input forms and settings panels (1100px).
  static const double formMaxContentWidth = 1100.0;

  /// Max content width for match scoreboard and live score control (850px).
  static const double scoreboardMaxContentWidth = 850.0;

  /// Max content width for admin dashboard and large management hubs (1600px).
  static const double dashboardMaxContentWidth = 1600.0;

  // ── Padding Tokens ─────────────────────────────────────────────────────────
  /// Mobile horizontal edge padding (16px).
  static const double mobilePadding = 16.0;

  /// Tablet horizontal edge padding (24px).
  static const double tabletPadding = 24.0;

  /// Desktop and ultrawide horizontal edge padding (32px).
  static const double desktopPadding = 32.0;

  // ── Query Methods (via BuildContext) ────────────────────────────────────────
  /// Returns `true` if current viewport width is strictly less than 600px.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  /// Returns `true` if current viewport width is between 600px (inclusive) and 1000px (exclusive).
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Returns `true` if current viewport width is between 1000px (inclusive) and 1800px (exclusive).
  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletBreakpoint && width < ultrawideBreakpoint;
  }

  /// Returns `true` if current viewport width is 1800px or greater.
  static bool isUltrawide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ultrawideBreakpoint;

  /// Returns `true` if current viewport width is 1000px or greater (desktop or ultrawide).
  ///
  /// Recommended for persistent navigation sidebars and multi-column forms where both
  /// desktop and ultrawide share the desktop layout structure.
  static bool isDesktopOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// Returns `true` if current viewport width is 600px or greater (tablet, desktop, or ultrawide).
  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  /// Returns `true` if current viewport width is strictly less than 1000px (mobile or tablet).
  ///
  /// Recommended when deciding whether to show an AppBar drawer or bottom bar.
  static bool isTabletOrSmaller(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tabletBreakpoint;

  // ── Query Methods (via raw width / BoxConstraints) ─────────────────────────
  /// Returns `true` if the given [width] is strictly less than 600px.
  static bool isMobileWidth(double width) => width < mobileBreakpoint;

  /// Returns `true` if the given [width] is between 600px and 1000px.
  static bool isTabletWidth(double width) =>
      width >= mobileBreakpoint && width < tabletBreakpoint;

  /// Returns `true` if the given [width] is between 1000px and 1800px.
  static bool isDesktopWidth(double width) =>
      width >= tabletBreakpoint && width < ultrawideBreakpoint;

  /// Returns `true` if the given [width] is 1800px or greater.
  static bool isUltrawideWidth(double width) => width >= ultrawideBreakpoint;

  /// Returns `true` if the given [width] is 1000px or greater.
  static bool isDesktopOrLargerWidth(double width) => width >= tabletBreakpoint;

  // ── Breakpoint Classification ──────────────────────────────────────────────
  /// Identifies the active [ResponsiveBreakpoint] for the given [context].
  static ResponsiveBreakpoint getBreakpoint(BuildContext context) =>
      getBreakpointFromWidth(MediaQuery.sizeOf(context).width);

  /// Identifies the active [ResponsiveBreakpoint] for a given [width].
  static ResponsiveBreakpoint getBreakpointFromWidth(double width) {
    if (width < mobileBreakpoint) return ResponsiveBreakpoint.mobile;
    if (width < tabletBreakpoint) return ResponsiveBreakpoint.tablet;
    if (width < ultrawideBreakpoint) return ResponsiveBreakpoint.desktop;
    return ResponsiveBreakpoint.ultrawide;
  }

  // ── Responsive Spacing & Padding ───────────────────────────────────────────
  /// Returns standard horizontal content padding based on viewport size:
  /// - Mobile (<600px): 16.0
  /// - Tablet (600-1000px): 24.0
  /// - Desktop & Ultrawide (>=1000px): 32.0
  static double contentPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileBreakpoint) return mobilePadding;
    if (width < tabletBreakpoint) return tabletPadding;
    return desktopPadding;
  }

  /// Returns an [EdgeInsets] with responsive horizontal padding and the specified [vertical] padding.
  static EdgeInsets contentPaddingInsets(
    BuildContext context, {
    double vertical = 16.0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: contentPadding(context),
      vertical: vertical,
    );
  }

  // ── Value Selector Helpers ─────────────────────────────────────────────────
  /// Selects a responsive value based on the current viewport width.
  ///
  /// Cascades upwards and downwards to provide seamless fallbacks:
  /// - `ultrawide`: falls back to `desktop`, then `tablet`, then `mobile`.
  /// - `desktop`: falls back to `tablet`, then `mobile`.
  /// - `tablet`: falls back to `mobile`.
  ///
  /// Example:
  /// ```dart
  /// int cols = ResponsiveLayout.value<int>(
  ///   context,
  ///   mobile: 1,
  ///   tablet: 2,
  ///   desktop: 3,
  /// );
  /// ```
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? ultrawide,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return valueFromWidth<T>(
      width,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      ultrawide: ultrawide,
    );
  }

  /// Selects a responsive value based on a provided [width] constraint.
  static T valueFromWidth<T>(
    double width, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? ultrawide,
  }) {
    if (width >= ultrawideBreakpoint) {
      return ultrawide ?? desktop ?? tablet ?? mobile;
    }
    if (width >= tabletBreakpoint) {
      return desktop ?? tablet ?? mobile;
    }
    if (width >= mobileBreakpoint) {
      return tablet ?? mobile;
    }
    return mobile;
  }

  /// Calculates a responsive grid cross-axis count.
  ///
  /// Example:
  /// ```dart
  /// int count = ResponsiveLayout.gridColumns(context, mobile: 1, tablet: 2, desktop: 3);
  /// ```
  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int? ultrawide,
  }) {
    return value<int>(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      ultrawide: ultrawide,
    );
  }
}

/// Shorthand alias class mirroring all [ResponsiveLayout] members.
///
/// Allows ergonomic calls like `Responsive.isMobile(context)` or `Responsive.value(context, ...)`.
abstract final class Responsive {
  Responsive._();

  // Breakpoints
  static const double mobileBreakpoint = ResponsiveLayout.mobileBreakpoint;
  static const double tabletBreakpoint = ResponsiveLayout.tabletBreakpoint;
  static const double ultrawideBreakpoint = ResponsiveLayout.ultrawideBreakpoint;

  // Max-Width Constraints
  static const double defaultMaxContentWidth = ResponsiveLayout.defaultMaxContentWidth;
  static const double formMaxContentWidth = ResponsiveLayout.formMaxContentWidth;
  static const double scoreboardMaxContentWidth = ResponsiveLayout.scoreboardMaxContentWidth;
  static const double dashboardMaxContentWidth = ResponsiveLayout.dashboardMaxContentWidth;

  // Padding
  static const double mobilePadding = ResponsiveLayout.mobilePadding;
  static const double tabletPadding = ResponsiveLayout.tabletPadding;
  static const double desktopPadding = ResponsiveLayout.desktopPadding;

  // Query Methods (BuildContext)
  static bool isMobile(BuildContext context) => ResponsiveLayout.isMobile(context);
  static bool isTablet(BuildContext context) => ResponsiveLayout.isTablet(context);
  static bool isDesktop(BuildContext context) => ResponsiveLayout.isDesktop(context);
  static bool isUltrawide(BuildContext context) => ResponsiveLayout.isUltrawide(context);
  static bool isDesktopOrLarger(BuildContext context) => ResponsiveLayout.isDesktopOrLarger(context);
  static bool isTabletOrLarger(BuildContext context) => ResponsiveLayout.isTabletOrLarger(context);
  static bool isTabletOrSmaller(BuildContext context) => ResponsiveLayout.isTabletOrSmaller(context);

  // Query Methods (Width)
  static bool isMobileWidth(double width) => ResponsiveLayout.isMobileWidth(width);
  static bool isTabletWidth(double width) => ResponsiveLayout.isTabletWidth(width);
  static bool isDesktopWidth(double width) => ResponsiveLayout.isDesktopWidth(width);
  static bool isUltrawideWidth(double width) => ResponsiveLayout.isUltrawideWidth(width);
  static bool isDesktopOrLargerWidth(double width) => ResponsiveLayout.isDesktopOrLargerWidth(width);

  // Breakpoints & Spacing
  static ResponsiveBreakpoint getBreakpoint(BuildContext context) => ResponsiveLayout.getBreakpoint(context);
  static ResponsiveBreakpoint getBreakpointFromWidth(double width) => ResponsiveLayout.getBreakpointFromWidth(width);
  static double contentPadding(BuildContext context) => ResponsiveLayout.contentPadding(context);
  static EdgeInsets contentPaddingInsets(BuildContext context, {double vertical = 16.0}) =>
      ResponsiveLayout.contentPaddingInsets(context, vertical: vertical);

  // Value Selectors
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? ultrawide,
  }) =>
      ResponsiveLayout.value<T>(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
        ultrawide: ultrawide,
      );

  static T valueFromWidth<T>(
    double width, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? ultrawide,
  }) =>
      ResponsiveLayout.valueFromWidth<T>(
        width,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
        ultrawide: ultrawide,
      );

  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int? ultrawide,
  }) =>
      ResponsiveLayout.gridColumns(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
        ultrawide: ultrawide,
      );
}

/// A container widget that centers its child, caps its maximum width to prevent infinite
/// stretching on desktop/ultrawide displays, and applies consistent responsive padding.
class ResponsiveContainer extends StatelessWidget {
  /// Creates a standard responsive container with [maxWidth] defaulting to 1440px.
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.defaultMaxContentWidth,
    this.padding,
    this.horizontalPadding,
    this.verticalPadding,
    this.alignment = Alignment.topCenter,
    this.fillWidth = true,
  });

  /// Preset for form pages (tournament creation, tournament edit, settings). Max-width: 1100px.
  const ResponsiveContainer.form({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.formMaxContentWidth,
    this.padding,
    this.horizontalPadding,
    this.verticalPadding,
    this.alignment = Alignment.topCenter,
    this.fillWidth = true,
  });

  /// Preset for scoreboard and match scoring control. Max-width: 850px.
  const ResponsiveContainer.scoreboard({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.scoreboardMaxContentWidth,
    this.padding,
    this.horizontalPadding,
    this.verticalPadding,
    this.alignment = Alignment.topCenter,
    this.fillWidth = true,
  });

  /// Preset for admin dashboard and large management hubs. Max-width: 1600px.
  const ResponsiveContainer.dashboard({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.dashboardMaxContentWidth,
    this.padding,
    this.horizontalPadding,
    this.verticalPadding,
    this.alignment = Alignment.topCenter,
    this.fillWidth = true,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// The maximum width allowed for this content area.
  final double maxWidth;

  /// Custom padding overriding the automatic responsive padding entirely.
  final EdgeInsetsGeometry? padding;

  /// Custom horizontal padding. If omitted, uses standard responsive padding (16 / 24 / 32px).
  final double? horizontalPadding;

  /// Custom vertical padding. Defaults to 16.0 if [padding] is not set.
  final double? verticalPadding;

  /// Alignment of the constrained content box within the available parent space.
  /// Defaults to [Alignment.topCenter] so page headers remain top-anchored while horizontally centered.
  final AlignmentGeometry alignment;

  /// Whether the child should expand to fill the maximum constrained width available.
  /// Defaults to `true` so grids, lists, and forms neatly span the container.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? ResponsiveLayout.contentPadding(context),
          vertical: verticalPadding ?? 16.0,
        );

    Widget content = Padding(
      padding: effectivePadding,
      child: fillWidth ? SizedBox(width: double.infinity, child: child) : child,
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

/// A builder widget that exposes the active [ResponsiveBreakpoint] to its build function.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  /// Builder callback invoked with context and the current [ResponsiveBreakpoint].
  final Widget Function(
    BuildContext context,
    ResponsiveBreakpoint breakpoint,
  ) builder;

  @override
  Widget build(BuildContext context) {
    final breakpoint = ResponsiveLayout.getBreakpoint(context);
    return builder(context, breakpoint);
  }
}

/// A builder widget that evaluates responsive breakpoints against local [BoxConstraints]
/// rather than the global screen size. Useful inside dialogs, bottom sheets, or nested columns.
class ResponsiveConstraintsBuilder extends StatelessWidget {
  const ResponsiveConstraintsBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    ResponsiveBreakpoint breakpoint,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = ResponsiveLayout.getBreakpointFromWidth(constraints.maxWidth);
        return builder(context, constraints, breakpoint);
      },
    );
  }
}

/// A slot-based widget that renders different children depending on the current breakpoint.
class ResponsiveWidget extends StatelessWidget {
  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.ultrawide,
  });

  /// Widget rendered when viewport is mobile (<600px).
  final Widget mobile;

  /// Widget rendered when viewport is tablet (600px - 1000px). Falls back to [mobile].
  final Widget? tablet;

  /// Widget rendered when viewport is desktop (1000px - 1800px). Falls back to [tablet], then [mobile].
  final Widget? desktop;

  /// Widget rendered when viewport is ultrawide (>=1800px). Falls back to [desktop], then [tablet], then [mobile].
  final Widget? ultrawide;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout.value<Widget>(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      ultrawide: ultrawide,
    );
  }
}

/// A convenience widget that lays out two widgets side-by-side ([Row]) on desktop/tablet,
/// and stacks them vertically ([Column]) on mobile. Ideal for 2-column input forms.
class ResponsiveTwoColumn extends StatelessWidget {
  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 16.0,
    this.breakpoint = ResponsiveLayout.tabletBreakpoint,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget left;
  final Widget right;
  final double spacing;
  final double breakpoint;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final isStacked = MediaQuery.sizeOf(context).width < breakpoint;
    if (isStacked) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          left,
          SizedBox(height: spacing),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Expanded(child: left),
        SizedBox(width: spacing),
        Expanded(child: right),
      ],
    );
  }
}
