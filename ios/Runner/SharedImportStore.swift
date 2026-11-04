import Foundation

/// Shared between the app, the share extension and the App Intents.
///
/// * A single "pending import" draft for shared text or images that the
///   person reviews right away.
/// * A queue of captured bank and wallet messages (JSON lines in the app
///   group container) that the app moves into its detection inbox. Writes go
///   through NSFileCoordinator so the app, the extension and Shortcuts never
///   corrupt each other's entries; delivery is at-least-once.
enum SharedImportStore {
  static let appGroupIdentifier = "group.com.basta.bastasaving.shared"
  static let pendingImportKey = "pending_import_payload"
  static let pendingRouteKey = "pending_route"
  private static let queueFile = "detection-queue.jsonl"
  private static let maxQueued = 1000

  static func save(
    source: String,
    rawText: String,
    recognizedText: String? = nil,
    imagePath: String? = nil
  ) {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

    let payload: [String: Any] = [
      "source": source,
      "rawText": rawText,
      "recognizedText": recognizedText ?? "",
      "imagePath": imagePath ?? "",
      "createdAt": ISO8601DateFormatter().string(from: Date())
    ]

    defaults.set(payload, forKey: pendingImportKey)
    defaults.synchronize()
  }

  static func consume() -> [String: Any]? {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
          let payload = defaults.dictionary(forKey: pendingImportKey) else {
      return nil
    }

    defaults.removeObject(forKey: pendingImportKey)
    defaults.synchronize()
    return payload
  }

  static func sharedContainerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
  }

  // MARK: - Pending route (opening a screen from a Shortcut)

  static func setPendingRoute(_ route: String) {
    UserDefaults(suiteName: appGroupIdentifier)?.set(route, forKey: pendingRouteKey)
  }

  static func consumePendingRoute() -> String? {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
    let route = defaults.string(forKey: pendingRouteKey)
    defaults.removeObject(forKey: pendingRouteKey)
    return route
  }

  // MARK: - Detection queue

  private static func queueURL() -> URL? {
    sharedContainerURL()?.appendingPathComponent(queueFile)
  }

  private static func coordinate(_ body: (URL) -> Void) {
    guard let url = queueURL() else { return }
    var error: NSError?
    NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &error) { body($0) }
  }

  private static func readLines(_ url: URL) -> [String] {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
  }

  private static func writeLines(_ lines: [String], to url: URL) {
    let text = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    try? text.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Removes full card numbers (keeps the last 4), national IDs, one-time
  /// codes and most of a phone number. Mirrors lib/core/detection/redact.dart.
  static func redact(_ text: String) -> String {
    var out = text
    func replace(_ pattern: String, options: NSRegularExpression.Options = [],
                 _ transform: (NSTextCheckingResult, NSString) -> String) {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
      let source = out as NSString
      var result = ""
      var last = 0
      for match in regex.matches(in: out, range: NSRange(location: 0, length: source.length)) {
        result += source.substring(with: NSRange(location: last, length: match.range.location - last))
        result += transform(match, source)
        last = match.range.location + match.range.length
      }
      result += source.substring(from: last)
      out = result
    }
    replace("(?<!\\d)(?:\\d[ -]?){12,18}\\d(?!\\d)") { match, source in
      let value = source.substring(with: match.range)
      let digits = value.filter(\.isNumber)
      if luhn(digits) { return "••••" + digits.suffix(4) }
      if digits.range(of: "^[23]\\d{13}$", options: .regularExpression) != nil { return "[ID]" }
      return value
    }
    replace("((?:otp|code|passcode|pin|رمز|كود|الرمز)\\D{0,12})(\\d{4,8})", options: .caseInsensitive) {
      match, source in source.substring(with: match.range(at: 1)) + "[CODE]"
    }
    replace("(?<!\\d)(\\+?20|0)(1[0125])(\\d{5})(\\d{3})(?!\\d)") { match, source in
      source.substring(with: match.range(at: 1)) + source.substring(with: match.range(at: 2))
        + "*****" + source.substring(with: match.range(at: 4))
    }
    return out
  }

  private static func luhn(_ digits: String) -> Bool {
    var sum = 0
    for (i, ch) in digits.reversed().enumerated() {
      guard var d = ch.wholeNumberValue else { return false }
      if i % 2 == 1 {
        d *= 2
        if d > 9 { d -= 9 }
      }
      sum += d
    }
    return sum % 10 == 0
  }

  /// Adds a captured message for the app to pick up.
  static func appendDetection(text: String, sender: String?, source: String, receivedAt: Date = Date()) {
    let entry: [String: Any] = [
      "id": UUID().uuidString,
      // Redacted before it touches disk, not later in Dart.
      "text": redact(text),
      "sender": (sender as Any?) ?? NSNull(),
      "receivedAt": ISO8601DateFormatter().string(from: receivedAt),
      "source": source
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: entry),
          let line = String(data: data, encoding: .utf8) else { return }
    coordinate { url in
      var lines = readLines(url)
      lines.append(line)
      writeLines(Array(lines.suffix(maxQueued)), to: url)
    }
  }

  /// Captured messages, oldest first.
  static func peekDetections(limit: Int = 200) -> [[String: Any]] {
    var out: [[String: Any]] = []
    coordinate { url in
      for line in readLines(url).prefix(limit) {
        if let data = line.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          out.append(object)
        }
      }
    }
    return out
  }

  /// Removes messages the app has stored.
  static func ackDetections(_ ids: [String]) {
    let done = Set(ids)
    coordinate { url in
      let keep = readLines(url).filter { line in
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["id"] as? String else { return false }
        return !done.contains(id)
      }
      writeLines(keep, to: url)
    }
  }
}
