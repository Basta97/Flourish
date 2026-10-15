import 'package:flutter/material.dart';
import '../../core/models/shared_import_draft.dart';
import '../../core/router/app_router.dart';
import '../../core/services/shared_import_service.dart';

/// Picks up text or images shared into Flourish (Android share sheet, iOS
/// share extension or Shortcuts) whichever tab is open, on launch and every
/// time the app returns to the foreground.
class ImportRuntime extends StatefulWidget {
  final Widget child;
  const ImportRuntime({super.key, required this.child});
  @override
  State<ImportRuntime> createState() => _ImportRuntimeState();
}

class _ImportRuntimeState extends State<ImportRuntime>
    with WidgetsBindingObserver {
  bool checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _import());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _import();
  }

  Future<void> _import() async {
    if (checking) return;
    checking = true;
    try {
      final SharedImportDraft? draft =
          await SharedImportService.consumePendingImport();
      if (mounted &&
          draft != null &&
          (draft.bestText.isNotEmpty || draft.imagePath != null)) {
        appRouter.push('/smart-import', extra: draft);
      }
    } catch (e) {
      debugPrint('Shared import unavailable: $e');
    } finally {
      checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
