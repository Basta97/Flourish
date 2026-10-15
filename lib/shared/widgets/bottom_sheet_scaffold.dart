import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/shared/widgets/app_card.dart';

class BottomSheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? headerTrailing;

  const BottomSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomClearance = keyboardInset > 0
        ? keyboardInset + Sp.md
        : Sp.bottomSheetClear;

    // Keep tall sheets clear of the status bar; content scrolls inside.
    // Modal sheets strip the top inset from MediaQuery, so read the window's.
    final view = View.of(context);
    final statusBar = view.viewPadding.top / view.devicePixelRatio;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - statusBar - Sp.sm,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, bottomClearance),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: AppCard(
              borderRadius: Rad.xl,
              padding: EdgeInsets.zero,
              bgColor: AppColors.elevatedSurface(context),
              // The handle and title sit outside the scrolling body, so a
              // downward drag there dismisses the sheet instead of scrolling.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.xl,
                      Sp.lg,
                      Sp.xl,
                      Sp.lg,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(Rad.full),
                          ),
                        ),
                        const SizedBox(height: Sp.lg),
                        Row(
                          children: [
                            Expanded(
                              child: Text(title, style: AppTextStyles.title),
                            ),
                            if (headerTrailing case final Widget trailing)
                              trailing,
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                        Sp.xl,
                        Sp.xs,
                        Sp.xl,
                        Sp.xl,
                      ),
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
