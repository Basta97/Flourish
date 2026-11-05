import 'package:flourish/shared/widgets/tap_bounce.dart';
import 'package:flutter/material.dart';

import '../../core/utils/amount_calculator.dart';
import '../../l10n/l10n.dart';
import 'bottom_sheet_scaffold.dart';
import 'spring_bottom_sheet.dart';

/// Keeps expressions out of the underlying amount controller: only an
/// explicitly accepted total reaches form validation and financial records.
class AmountCalculatorButton extends StatelessWidget {
  const AmountCalculatorButton({
    super.key,
    required this.controller,
    this.onChanged,
    this.decimalPlaces,
    this.allowNegative = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int? decimalPlaces;
  final bool allowNegative;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TapBounce(
    child: IconButton(
      tooltip: context.l10n.amountCalculator,
      icon: const Icon(Icons.calculate_rounded),
      onPressed: !enabled
          ? null
          : () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final total = await showSpringBottomSheet<String>(
                context: context,
                builder: (_) => _CalculatorSheet(
                  initial: controller.text,
                  decimalPlaces: decimalPlaces,
                  allowNegative: allowNegative,
                ),
              );
              if (total == null || !context.mounted) return;
              controller.value = TextEditingValue(
                text: total,
                selection: TextSelection.collapsed(offset: total.length),
              );
              onChanged?.call(total);
            },
    ),
  );
}

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet({
    required this.initial,
    required this.decimalPlaces,
    required this.allowNegative,
  });

  final String initial;
  final int? decimalPlaces;
  final bool allowNegative;

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  late final _expression = TextEditingController(text: widget.initial)
    ..selection = TextSelection.collapsed(offset: widget.initial.length);
  CalculationError? _error;

  @override
  void dispose() {
    _expression.dispose();
    super.dispose();
  }

  void _key(String key) {
    if (key == '=') {
      try {
        final result = AmountCalculator.evaluate(
          _expression.text,
          decimalPlaces: widget.decimalPlaces,
          allowNegative: widget.allowNegative,
        );
        Navigator.pop(context, result.toString());
      } on CalculationError catch (error) {
        setState(() => _error = error);
      }
      return;
    }
    setState(() => _error = null);
    if (key == 'AC') {
      _expression.clear();
      return;
    }
    final text = _expression.text;
    final selection = _expression.selection;
    var start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    if (key == '⌫') {
      if (start == end && start > 0) start--;
      key = '';
    }
    final next = text.replaceRange(start, end, key);
    if (next.length > 512) return;
    _expression.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + key.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    const rows = [
      ['AC', '(', ')', '⌫'],
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '−'],
      ['.', '0', '=', '+'],
    ];
    return BottomSheetScaffold(
      title: l.amountCalculator,
      headerTrailing: TapBounce(
        child: IconButton(
          tooltip: l.cancel,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      children: [
        Text(l.calculatorUseTotal),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('calculator-expression'),
          controller: _expression,
          readOnly: true,
          showCursor: true,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: InputDecoration(
            hintText: '0',
            errorMaxLines: 3,
            errorText: switch (_error) {
              CalculationError.incomplete => l.calculatorCheckExpression,
              CalculationError.divideByZero => l.calculatorDivideByZero,
              CalculationError.negative => l.calculatorNegativeTotal,
              null => null,
            },
          ),
        ),
        const SizedBox(height: 16),
        // Arithmetic retains its familiar left-to-right keypad in Arabic.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (final key in row)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: FilledButton(
                              key: ValueKey('calculator-$key'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                padding: EdgeInsets.zero,
                                backgroundColor: key == '='
                                    ? colors.primary
                                    : '+−×÷'.contains(key)
                                    ? colors.primary.withValues(alpha: 0.12)
                                    : colors.surfaceContainerHighest,
                                foregroundColor: key == '='
                                    ? colors.onPrimary
                                    : key == 'AC'
                                    ? colors.error
                                    : '+−×÷'.contains(key)
                                    ? colors.primary
                                    : colors.onSurface,
                              ),
                              onPressed: () => _key(key),
                              child: key == '⌫'
                                  ? Icon(
                                      Icons.backspace_rounded,
                                      semanticLabel: l.calculatorBackspace,
                                    )
                                  : Text(
                                      key,
                                      semanticsLabel: key == 'AC'
                                          ? l.calculatorClear
                                          : null,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
