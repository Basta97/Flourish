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

  /// Adds a captured message for the app to pick up.
  static func appendDetection(text: String, sender: String?, source: String, receivedAt: Date = Date()) {
    let entry: [String: Any] = [
      "id": UUID().uuidString,
      "text": text,
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
