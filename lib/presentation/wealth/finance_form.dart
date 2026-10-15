import 'package:flutter/material.dart';
import '../../core/utils/error_text.dart';

class FinanceField {
  final String key, label, initial;
  final Map<String, String>? options;
  final bool numeric, date, secret, required;
  const FinanceField(
    this.key,
    this.label, {
    this.initial = '',
    this.options,
    this.numeric = false,
    this.date = false,
    this.secret = false,
    this.required = true,
  });
}

Future<bool?> financeForm(
  BuildContext context, {
  required String title,
  required List<FinanceField> fields,
  required Future<void> Function(Map<String, String>) save,
  String submit = 'Save',
}) => showDialog<bool>(
  context: context,
  builder: (_) =>
      _FinanceForm(title: title, fields: fields, save: save, submit: submit),
);

class _FinanceForm extends StatefulWidget {
  final String title, submit;
  final List<FinanceField> fields;
  final Future<void> Function(Map<String, String>) save;
  const _FinanceForm({
    required this.title,
    required this.fields,
    required this.save,
    required this.submit,
  });
  @override
  State<_FinanceForm> createState() => _FinanceFormState();
}

class _FinanceFormState extends State<_FinanceForm> {
  late final values = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initial),
  };
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in values.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: f.options != null
                    ? DropdownButtonFormField<String>(
                        key: ValueKey(f.key),
                        initialValue:
                            f.options!.containsKey(values[f.key]!.text)
                            ? values[f.key]!.text
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: f.label),
                        items: f.options!.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (v) => values[f.key]!.text = v ?? '',
                      )
                    : TextField(
                        key: ValueKey(f.key),
                        controller: values[f.key],
                        obscureText: f.secret,
                        readOnly: f.date,
                        keyboardType: f.numeric
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              )
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: f.label,
                          suffixIcon: f.date
                              ? const Icon(Icons.calendar_today)
                              : null,
                        ),
                        onTap: !f.date
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      DateTime.tryParse(values[f.key]!.text) ??
                                      DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2126),
                                );
                                if (date != null) {
                                  values[f.key]!.text = date
                                      .toIso8601String()
                                      .substring(0, 10);
                                }
                              },
                      ),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                final data = {
                  for (final e in values.entries) e.key: e.value.text.trim(),
                };
                for (final f in widget.fields) {
                  if (f.required && data[f.key]!.isEmpty) {
                    setState(() => error = 'Enter ${f.label.toLowerCase()}');
                    return;
                  }
                }
                setState(() {
                  saving = true;
                  error = null;
                });
                try {
                  await widget.save(data);
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      saving = false;
                      error = describeError(e);
                    });
                  }
                }
              },
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.submit),
      ),
    ],
  );
}
