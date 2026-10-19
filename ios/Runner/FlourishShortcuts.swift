import AppIntents
import Foundation
import UserNotifications

/// Shortcuts actions that hand bank and wallet messages to Flourish without
/// opening it. They only queue the text; parsing and matching happen in the
/// app, which shows them in the payments inbox for review.
@available(iOS 16.0, *)
struct ImportTransactionTextIntent: AppIntent {
  static let title: LocalizedStringResource = "Import Transaction Text"
  static let description = IntentDescription(
    "Send a bank or wallet SMS to Flourish's payments inbox. Use it in a Message automation."
  )
  // Runs in the background so a Message automation can "Run Immediately".
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Transaction Text")
  var transactionText: String

  @Parameter(title: "Sender")
  var sender: String?

  /// When the message arrived. Set it from "Find Messages" so a catch-up
  /// keeps each message's real date and running it again adds nothing twice.
  @Parameter(title: "Received")
  var received: Date?

  static var parameterSummary: some ParameterSummary {
    Summary("Import \(\.$transactionText) into Flourish") {
      \.$sender
      \.$received
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    SharedImportStore.appendDetection(
      text: transactionText,
      sender: sender,
      source: "ios_shortcut",
      receivedAt: received ?? Date()
    )
    await PaymentNotice.post()
    return .result(dialog: "Saved to Flourish for review")
  }
}

/// For the Wallet "Transaction" automation, which provides the amount,
/// merchant and card of an Apple Pay payment.
@available(iOS 16.0, *)
struct LogCardPaymentIntent: AppIntent {
  static let title: LocalizedStringResource = "Log Card Payment"
  static let description = IntentDescription(
    "Record an Apple Pay payment in Flourish's payments inbox. Use it in a Wallet automation."
  )
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Amount")
  var amount: String

  @Parameter(title: "Merchant")
  var merchant: String?

  @Parameter(title: "Card")
  var card: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$amount) at \(\.$merchant) in Flourish") {
      \.$card
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    var text = "Apple Pay purchase of \(amount)"
    if let merchant, !merchant.isEmpty { text += " at \(merchant)" }
    if let card, !card.isEmpty { text += " with card \(card)" }
    SharedImportStore.appendDetection(text: text, sender: "Apple Pay", source: "ios_wallet")
    await PaymentNotice.post()
    return .result(dialog: "Saved to Flourish for review")
  }
}

@available(iOS 16.0, *)
struct OpenPaymentInboxIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Payments to Review"
  static let openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    SharedImportStore.setPendingRoute("/inbox")
    return .result()
  }
}

/// A quiet local notification that opens the inbox when tapped.
enum PaymentNotice {
  static func post() async {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .authorized ||
      settings.authorizationStatus == .provisional else { return }
    let content = UNMutableNotificationContent()
    content.title = "Payment to review"
    content.body = "Tap to add it to Flourish."
    // flutter_local_notifications forwards this payload to the app.
    content.userInfo = ["payload": "route:/inbox"]
    let request = UNNotificationRequest(
      identifier: "flourish-detected-payment",
      content: content,
      trigger: nil
    )
    try? await center.add(request)
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
      ),
      AppShortcut(
        intent: LogCardPaymentIntent(),
        phrases: ["Log card payment in \(.applicationName)"],
        shortTitle: "Log Card Payment",
        systemImageName: "wallet.pass"
      ),
      AppShortcut(
        intent: OpenPaymentInboxIntent(),
        phrases: ["Review payments in \(.applicationName)"],
        shortTitle: "Payments to Review",
        systemImageName: "tray.full"
      )
    ]
  }
}
