import Foundation

enum SharedImportStore {
  static let appGroupIdentifier = "group.com.basta.bastasaving.shared"
  static let pendingImportKey = "pending_import_payload"

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
}
