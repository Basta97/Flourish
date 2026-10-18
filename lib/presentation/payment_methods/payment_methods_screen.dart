import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/liquid_page.dart';
import '../accounts/widgets/payment_instruments_section.dart';
import '../providers/account_providers.dart';

/// Every account's cards and wallets in one place.
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = (ref.watch(accountsProvider).valueOrNull ?? const [])
        .where((a) => a.type != 'cash')
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.cardsWallets)),
      body: LiquidPageBackground(
        child: accounts.isEmpty
            ? EmptyState(
                icon: Icons.credit_card_rounded,
                title: context.l10n.noPaymentAccounts,
                subtitle: context.l10n.addOneFromAccounts,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(Sp.xl),
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: Sp.lg),
                itemBuilder: (_, i) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: Sp.xs,
                        bottom: Sp.sm,
                      ),
                      child: Text(
                        '${accounts[i].name} · ${accounts[i].currency}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    PaymentInstrumentsSection(account: accounts[i]),
                  ],
                ),
              ),
      ),
    );
  }
}
