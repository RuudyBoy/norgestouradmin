import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Kontrollpanel – rene visningskomponenter for admin («ryddigere design»).
///
/// Disse widgetene inneholder INGEN forretningslogikk og gjør ingen
/// Firestore-kall. De tar imot ferdige verdier og callbacks fra sidene.

// ════════════════════════════════════════════════════════════════════════════
// Tekst
// ════════════════════════════════════════════════════════════════════════════

class AdminText {
  AdminText._();

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.adminText,
    double? height,
    FontStyle? style,
    double? letterSpacing,
  }) =>
      GoogleFonts.schibstedGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontStyle: style,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.adminText,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// ALL-CAPS kicker («KONTROLLPANEL», «MENY», «KLASSE»).
  static TextStyle kicker({Color color = AppColors.adminTextSecondary}) =>
      GoogleFonts.ibmPlexMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.32,
        color: color,
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Flater
// ════════════════════════════════════════════════════════════════════════════

/// Hvitt kort med 1px kant, 12px radius og svak skygge.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const AdminCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    Widget content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: radius, child: content);
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.adminSurface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.adminOutline, width: borderWidth),
        boxShadow: const [
          BoxShadow(color: Color(0x0A111827), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(borderRadius: radius, child: content),
      ),
    );
  }
}

/// Kortoverskrift: tittel til venstre, valgfritt innhold til høyre, skillelinje under.
class AdminCardHeader extends StatelessWidget {
  final String title;
  final Widget? count;
  final Widget? trailing;
  final Widget? leading;

  const AdminCardHeader({super.key, required this.title, this.count, this.trailing, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.adminDivider)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Flexible(
            child: Text(title,
                style: AdminText.ui(size: 16, weight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          if (count != null) ...[const SizedBox(width: 8), count!],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Kicker + stor tittel øverst på en side, med valgfri handling til høyre.
class AdminPageHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final Widget? action;
  final Widget? leading;

  const AdminPageHeader({super.key, required this.kicker, required this.title, this.action, this.leading});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 16,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kicker.toUpperCase(), style: AdminText.kicker()),
                const SizedBox(height: 6),
                Text(title,
                    style: AdminText.ui(size: 30, weight: FontWeight.w700, letterSpacing: -0.3)),
              ],
            ),
          ],
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// Ikonflis (40×40, radius 10) – trofé ved turneringer, ikon i KPI-kort o.l.
class AdminIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;
  final double iconSize;
  final double radius;

  const AdminIconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.background = AppColors.adminInfoBg,
    this.foreground = AppColors.adminPrimary,
    this.iconSize = 20,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Merker / statuspiller
// ════════════════════════════════════════════════════════════════════════════

class AdminPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool dot;
  final double height;
  final double fontSize;
  final bool mono;

  const AdminPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.dot = false,
    this.height = 24,
    this.fontSize = 12,
    this.mono = false,
  });

  /// LIVE – coral med ink-tekst (lesbar kontrast).
  const AdminPill.live({super.key, this.label = 'LIVE', this.dot = false, this.height = 24})
      : background = AppColors.coral,
        foreground = AppColors.ink,
        fontSize = 12,
        mono = false;

  /// Ferdig / Walkover / Åpen / Publisert – grønn.
  const AdminPill.success(this.label, {super.key, this.height = 24})
      : background = const Color(0x1F1F7556),
        foreground = AppColors.green,
        dot = false,
        fontSize = 12,
        mono = false;

  /// Planlagt / Venter... / Stengt – nøytral.
  const AdminPill.neutral(this.label, {super.key, this.height = 24})
      : background = AppColors.adminSurfaceElevated,
        foreground = AppColors.adminTextMuted,
        dot = false,
        fontSize = 12,
        mono = false;

  /// Kommende / type / info – blå.
  const AdminPill.info(this.label, {super.key, this.height = 24})
      : background = AppColors.adminInfoBg,
        foreground = AppColors.adminPrimaryDark,
        dot = false,
        fontSize = 12,
        mono = false;

  /// +Nmin – forsinket.
  const AdminPill.delayed(this.label, {super.key, this.height = 24})
      : background = const Color(0x143311DB),
        foreground = AppColors.adminPrimaryHover,
        dot = false,
        fontSize = 12,
        mono = false;

  /// Teller-merke (badge) – f.eks. antall ventende.
  const AdminPill.count(this.label, {super.key, this.background = AppColors.adminPrimary, this.foreground = Colors.white})
      : dot = false,
        height = 20,
        fontSize = 12,
        mono = false;

  @override
  Widget build(BuildContext context) {
    final style = mono
        ? AdminText.mono(size: fontSize, weight: FontWeight.w600, color: foreground)
        : AdminText.ui(size: fontSize, weight: FontWeight.w600, color: foreground);
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height <= 20 ? 7 : 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: style, maxLines: 1),
        ],
      ),
    );
  }
}

/// Kampstatus → riktig pille (status-ord alltid synlig, aldri bare farge).
class AdminMatchStatusPill extends StatelessWidget {
  /// 'LIVE', 'Ferdig', 'Walkover', 'Planlagt', 'Venter...', '+Nmin'
  final String label;
  const AdminMatchStatusPill(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    if (label == 'LIVE') return const AdminPill.live();
    if (label == 'Ferdig' || label == 'Walkover') return AdminPill.success(label);
    if (label.startsWith('+')) return AdminPill.delayed(label);
    return AdminPill.neutral(label);
  }
}

/// Liten teller i monospace («7», «96») ved siden av en etikett.
class AdminCount extends StatelessWidget {
  final String value;
  final bool boxed;
  final Color? color;
  const AdminCount(this.value, {super.key, this.boxed = false, this.color});

  @override
  Widget build(BuildContext context) {
    final text = Text(value,
        style: AdminText.mono(size: 11, color: color ?? (boxed ? AppColors.adminTextMuted : AppColors.adminTextSecondary)));
    if (!boxed) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.adminMuted, borderRadius: BorderRadius.circular(4)),
      child: text,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Knapper
// ════════════════════════════════════════════════════════════════════════════

/// Sekundærknapp (hvit, 1px kant) eller primærknapp (blå).
class AdminButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final double height;
  final Widget? badge;
  final Widget? trailingIcon;
  final Color? foreground;
  final Color? borderColor;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const AdminButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.height = 44,
    this.badge,
    this.trailingIcon,
    this.foreground,
    this.borderColor,
    this.fontSize = 14,
    this.padding,
  });

  const AdminButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 44,
    this.badge,
    this.trailingIcon,
    this.fontSize = 14,
    this.padding,
  })  : primary = true,
        foreground = null,
        borderColor = null;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? (primary ? Colors.white : AppColors.adminText);
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStatePropertyAll(padding ?? EdgeInsets.symmetric(horizontal: height >= 52 ? 22 : 16)),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      side: WidgetStateProperty.resolveWith((states) {
        if (primary) return BorderSide.none;
        if (states.contains(WidgetState.hovered)) {
          return const BorderSide(color: Color(0xFFCBD5E1));
        }
        return BorderSide(color: borderColor ?? AppColors.adminOutline);
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (primary) {
          if (states.contains(WidgetState.disabled)) return AppColors.adminMuted;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
            return AppColors.adminPrimaryDark;
          }
          return AppColors.adminPrimary;
        }
        return AppColors.adminSurface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.adminTextSecondary;
        return fg;
      }),
      overlayColor: WidgetStatePropertyAll(primary ? Colors.white.withValues(alpha: 0.06) : AppColors.adminSurfaceElevated),
      textStyle: WidgetStatePropertyAll(AdminText.ui(size: fontSize, weight: FontWeight.w600)),
    );
    return TextButton(
      style: style,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(label, maxLines: 1),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
          if (trailingIcon != null) ...[const SizedBox(width: 6), trailingIcon!],
        ],
      ),
    );
  }
}

/// Ikonknapp uten ramme (44×44 / 40×40 / 36×36).
class AdminGhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  final double iconSize;
  final Color? background;

  const AdminGhostIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 40,
    this.iconSize = 18,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: background ?? Colors.transparent,
      borderRadius: BorderRadius.circular(size >= 40 ? 10 : 8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size >= 40 ? 10 : 8),
        hoverColor: AppColors.adminMuted,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color ?? AppColors.adminTextMuted),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Filtre og kontroller
// ════════════════════════════════════════════════════════════════════════════

class AdminSegmentItem<T> {
  final T value;
  final String? label;
  final IconData? icon;
  final String? count;
  final String? tooltip;
  const AdminSegmentItem({required this.value, this.label, this.icon, this.count, this.tooltip});
}

/// Segmentert kontroll: grå bakgrunn, valgt element hvitt med skygge.
class AdminSegmented<T> extends StatelessWidget {
  final List<AdminSegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  const AdminSegmented({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.adminMuted, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _segment(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _segment(AdminSegmentItem<T> item) {
    final on = item.value == selected;
    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: item.label == null ? 12 : 14),
      decoration: BoxDecoration(
        color: on ? AppColors.adminSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: on
            ? const [BoxShadow(color: Color(0x1F111827), blurRadius: 3, offset: Offset(0, 1))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null)
            Icon(item.icon, size: 16, color: on ? AppColors.adminText : AppColors.adminTextMuted),
          if (item.icon != null && item.label != null) const SizedBox(width: 6),
          if (item.label != null)
            Text(item.label!,
                style: AdminText.ui(
                    size: 13, weight: FontWeight.w600, color: on ? AppColors.adminText : AppColors.adminTextMuted)),
          if (item.count != null) ...[
            const SizedBox(width: 6),
            Text(item.count!, style: AdminText.mono(size: 11, color: AppColors.adminTextSecondary)),
          ],
        ],
      ),
    );
    child = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => onChanged(item.value), child: child),
    );
    if (item.tooltip != null) child = Tooltip(message: item.tooltip!, child: child);
    return child;
  }
}

/// Rad med avrundede «scope»-knapper (Klasse-filter). Valgt = navy.
class AdminScopeChips<T> extends StatelessWidget {
  final String? label;
  final List<AdminSegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  const AdminScopeChips({super.key, this.label, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(label!.toUpperCase(), style: AdminText.kicker()),
          ),
        for (final item in items) AdminScopeChip(
          label: item.label ?? '',
          count: item.count,
          selected: item.value == selected,
          onTap: () => onChanged(item.value),
        ),
      ],
    );
  }
}

class AdminScopeChip extends StatelessWidget {
  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  const AdminScopeChip({
    super.key,
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.adminTextMuted;
    return Material(
      color: selected ? AppColors.adminSidebarBg : AppColors.adminSurface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.adminSidebarBg : AppColors.adminOutline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AdminText.ui(size: 13, weight: FontWeight.w600, color: fg)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(count!, style: AdminText.mono(size: 11, color: fg.withValues(alpha: 0.75))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Søkefelt (44 høyt, ikon til venstre).
class AdminSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final double maxWidth;

  const AdminSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.maxWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 200),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: AdminText.ui(size: 14),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.adminTextSecondary),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ),
    );
  }
}

/// Nedtrekksvelger i stilen «Sorter: Startdato ⌄».
class AdminSelect<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<AdminSegmentItem<T>> options;
  final ValueChanged<T> onChanged;

  const AdminSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.value == value);
    final currentLabel = current.isEmpty ? '' : (current.first.label ?? '');
    return PopupMenuButton<T>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<T>(
            value: o.value,
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: o.value == value
                      ? const Icon(Icons.check, size: 16, color: AppColors.adminPrimary)
                      : null,
                ),
                Text(o.label ?? '',
                    style: AdminText.ui(
                        size: 14,
                        weight: o.value == value ? FontWeight.w600 : FontWeight.w400)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
        decoration: BoxDecoration(
          color: AppColors.adminSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.adminOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ', style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
            Flexible(
              child: Text(currentLabel,
                  style: AdminText.ui(size: 14, weight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.adminTextSecondary),
          ],
        ),
      ),
    );
  }
}

/// Fremdriftsstolpe (avrundet spor + fyll).
class AdminProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final Color track;
  final double height;
  final double? width;

  const AdminProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.adminPrimary,
    this.track = AppColors.adminMuted,
    this.height = 4,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
              child: SizedBox(height: height),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faneknapp med blå understrek (Oversikt / Kampprogram / Oppsett / Lag).
class AdminTab extends StatelessWidget {
  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  const AdminTab({super.key, required this.label, this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Container(
        height: 48,
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: selected ? AppColors.adminPrimary : Colors.transparent, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AdminText.ui(
                    size: 15,
                    weight: FontWeight.w600,
                    color: selected ? AppColors.adminPrimary : AppColors.adminTextSecondary)),
            if (count != null) ...[const SizedBox(width: 8), AdminCount(count!, boxed: true)],
          ],
        ),
      ),
    );
  }
}

/// Info-stripe (lys blå) – f.eks. «Velg lag å bytte med …».
class AdminInfoBanner extends StatelessWidget {
  final IconData icon;
  final Widget message;
  final Widget? action;

  const AdminInfoBanner({super.key, required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.adminInfoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.adminInfoBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.adminPrimary),
          const SizedBox(width: 12),
          Expanded(child: DefaultTextStyle(style: AdminText.ui(size: 14), child: message)),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// Tabelloverskrift-celle (12px, grå, F8FAFC-bakgrunn settes av raden).
class AdminTh extends StatelessWidget {
  final String text;
  final TextAlign align;
  const AdminTh(this.text, {super.key, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: AdminText.ui(size: 12, weight: FontWeight.w600, color: AppColors.adminTextSecondary),
        overflow: TextOverflow.ellipsis,
      );
}

/// Liten etikett + verdi (stat i kort).
class AdminStat extends StatelessWidget {
  final String label;
  final Widget value;
  const AdminStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AdminText.ui(size: 12, color: AppColors.adminTextSecondary)),
        const SizedBox(height: 2),
        value,
      ],
    );
  }
}

/// Gir innholdet en minimumsbredde; ruller horisontalt når plassen er mindre.
class AdminHScroll extends StatelessWidget {
  final double minWidth;
  final Widget child;
  const AdminHScroll({super.key, required this.minWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= minWidth) return child;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: minWidth, child: child),
      );
    });
  }
}

/// Tabellrad med hover-farge og skillelinje under.
class AdminHoverRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color background;
  final Color? hoverColor;

  const AdminHoverRow({
    super.key,
    required this.child,
    this.onTap,
    this.background = AppColors.adminSurface,
    this.hoverColor,
  });

  @override
  State<AdminHoverRow> createState() => _AdminHoverRowState();
}

class _AdminHoverRowState extends State<AdminHoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _hover ? (widget.hoverColor ?? AppColors.adminRowHover) : widget.background,
            border: const Border(bottom: BorderSide(color: AppColors.adminDivider)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Sideinnhold: sentrert, toppforankret, maks bredde 1240 og responsiv luft
/// (16 / 24 / 32 px etter brekkpunkt).
class AdminPageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double? top;
  final double bottom;

  const AdminPageBody({super.key, required this.child, this.maxWidth = 1240, this.top, this.bottom = 40});

  static double padFor(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return 16;
    if (w < 1000) return 24;
    return 32;
  }

  @override
  Widget build(BuildContext context) {
    final pad = padFor(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, top ?? (pad < 32 ? pad : 32), pad, bottom),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Tom tilstand – sentrert ikon og tekst.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const AdminEmptyState({super.key, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminIconTile(icon: icon, size: 56, iconSize: 28, radius: 14,
                background: AppColors.adminMuted, foreground: AppColors.adminTextSecondary),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: AdminText.ui(size: 14, color: AppColors.adminTextSecondary)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
