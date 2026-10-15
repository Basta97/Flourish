import Social
import UIKit
import UniformTypeIdentifiers
import Vision

final class ShareViewController: SLComposeServiceViewController {
  override func isContentValid() -> Bool {
    true
  }

  override func didSelectPost() {
    Task {
      await handleSharedContent()
      extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
  }

  override func configurationItems() -> [Any]! {
    []
  }

  private func handleSharedContent() async {
    let extraText = contentText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      if !extraText.isEmpty {
        SharedImportStore.save(source: "share-extension", rawText: extraText)
      }
      return
    }

    var mergedText = extraText
    var recognizedText = ""
    var savedImagePath: String?

    for item in items {
      guard let attachments = item.attachments else { continue }
      for provider in attachments {
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = await loadText(from: provider) {
          if !mergedText.isEmpty { mergedText += "\n" }
          mergedText += text
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                  let image = await loadImage(from: provider) {
          recognizedText = await recognizeText(in: image)
          savedImagePath = saveImageToSharedContainer(image)
        }
      }
    }

    if !mergedText.isEmpty || !recognizedText.isEmpty || savedImagePath != nil {
      SharedImportStore.save(
        source: "share-extension",
        rawText: mergedText,
        recognizedText: recognizedText,
        imagePath: savedImagePath
      )
    }
  }

  private func loadText(from provider: NSItemProvider) async -> String? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
        if let text = item as? String {
          continuation.resume(returning: text)
        } else if let url = item as? URL, let text = try? String(contentsOf: url) {
          continuation.resume(returning: text)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private func loadImage(from provider: NSItemProvider) async -> UIImage? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
        if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
          continuation.resume(returning: image)
        } else if let image = item as? UIImage {
          continuation.resume(returning: image)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private func recognizeText(in image: UIImage) async -> String {
    guard let cgImage = image.cgImage else { return "" }

    return await withCheckedContinuation { continuation in
      let request = VNRecognizeTextRequest { request, _ in
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations
          .compactMap { $0.topCandidates(1).first?.string }
          .joined(separator: "\n")
        continuation.resume(returning: text)
      }
      request.recognitionLevel = .accurate
      // Read Arabic receipts and screenshots where Vision supports it.
      if let supported = try? request.supportedRecognitionLanguages() {
        let arabic = supported.filter { $0.hasPrefix("ar") }
        if !arabic.isEmpty { request.recognitionLanguages = arabic + ["en-US"] }
      }
      request.usesLanguageCorrection = true

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try handler.perform([request])
      } catch {
        continuation.resume(returning: "")
      }
    }
  }

  private func saveImageToSharedContainer(_ image: UIImage) -> String? {
    guard let container = SharedImportStore.sharedContainerURL(),
          let data = image.jpegData(compressionQuality: 0.85) else {
      return nil
    }

    let fileURL = container.appendingPathComponent("shared-import-\(UUID().uuidString).jpg")
    do {
      try data.write(to: fileURL)
      return fileURL.path
    } catch {
      return nil
    }
  }
}
