import AppIntents
import Foundation

@available(iOS 16.0, *)
struct ImportTransactionTextIntent: AppIntent {
  static let title: LocalizedStringResource = "Import Transaction Text"
  static let description = IntentDescription("Send bank SMS or email text into Flourish and open a review draft.")
  static let openAppWhenRun: Bool = true

  @Parameter(title: "Transaction Text")
  var transactionText: String

  static var parameterSummary: some ParameterSummary {
    Summary("Import \(\.$transactionText) into Flourish")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    SharedImportStore.save(source: "shortcut", rawText: transactionText)
    return .result(dialog: "Ready in Flourish")
  }
}

@available(iOS 16.0, *)
struct FlourishShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    return [
      AppShortcut(
        intent: ImportTransactionTextIntent(),
        phrases: [
          "Import transaction text in \(.applicationName)",
          "Log bank message with \(.applicationName)",
          "Save payment alert in \(.applicationName)"
        ],
        shortTitle: "Import Transaction",
        systemImageName: "creditcard.and.123"
      )
    ]
  }
}
