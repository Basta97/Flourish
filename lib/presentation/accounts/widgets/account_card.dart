import 'package:flutter/material.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/utils/icon_utils.dart';
import 'package:flourish/data/database/database.dart';

/// Hero tag shared by the Accounts list card and the detail header.
String accountHeroTag(int id) => 'account-card-$id';

/// Bank-card style tile for an account: the account's gradient, a soft sheen,
/// type and currency up top, name and balance below.
///
/// The same widget renders in the list and in the detail header, so the Hero
/// flight between them morphs one card instead of cross-fading two.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account, this.large = false});

  final Account account;

  /// Taller card with a bigger balance, for the detail header.
  final bool large;

  /// The stored color is the first stop of one of [AppColors.accountGradients];
  /// fall back to a tonal pair for colors saved before the palette existed.
  static List<Color> gradientFor(int color) {
    for (final g in AppColors.accountGradients) {
      if (g.first.toARGB32() == color) return g;
    }
    // Calm it down: cap saturation so off-palette colors sit with the rest.
    final hsl = HSLColor.fromColor(Color(color));
    final calm = hsl.withSaturation(hsl.saturation.clamp(0, 0.5));
    return [
      calm.withLightness((hsl.lightness * 0.62).clamp(0, 1)).toColor(),
      calm.withLightness((hsl.lightness * 1.1).clamp(0, 0.72)).toColor(),
    ];
  }

  static const _onCard = Color(0xFFF7F9FB);

  @override
  Widget build(BuildContext context) {
    final colors = gradientFor(account.color);
    final negative = account.balance < 0;
    final radius = BorderRadius.circular(Rad.xl);

    // Material keeps Text styling intact while the card flies in a Hero.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: large ? 196 : 164,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.first,
              Color.lerp(colors.first, colors.last, 0.55)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              // Soft sheen: two translucent discs, like light on a card.
              Positioned(
                right: -60,
                top: -70,
                child: _Disc(size: 200, alpha: 0.10),
              ),
              Positioned(
                right: 40,
                bottom: -90,
                child: _Disc(size: 160, alpha: 0.06),
              ),
              // Hairline highlight along the top edge.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(large ? Sp.xxl : Sp.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(Rad.md),
                          ),
                          child: Icon(
                            IconUtils.accountIcon(account.icon),
                            color: _onCard,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: Sp.md),
                        Text(
                          account.type.toUpperCase(),
                          style: AppTextStyles.eyebrow.copyWith(
                            color: _onCard.withValues(alpha: 0.75),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(Rad.full),
                          ),
                          child: Text(
                            account.currency,
                            style: AppTextStyles.caption.copyWith(
                              color: _onCard,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _onCard.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: Sp.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(
                          account.balance,
                          currency: account.currency,
                        ),
                        style:
                            (large
                                    ? AppTextStyles.numberLarge
                                    : AppTextStyles.number.copyWith(
                                        fontSize: 24,
                                      ))
                                .copyWith(
                                  color: negative
                                      ? const Color(0xFFFFC2BA)
                                      : _onCard,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}
