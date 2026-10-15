import Flutter
import UIKit
import Vision

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    configureImportChannel()
  }

  private func configureImportChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    let importChannel = FlutterMethodChannel(
      name: "flourish/imports",
      binaryMessenger: controller.binaryMessenger
    )

    importChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "consumePendingImport":
        result(SharedImportStore.consume())
      case "recognizeImage":
        guard let path = call.arguments as? String,
              let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
          result(FlutterError(code: "image", message: "Could not open image", details: nil)); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let request = VNRecognizeTextRequest()
          request.recognitionLevel = .accurate
          request.usesLanguageCorrection = true
          do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            DispatchQueue.main.async { result(text) }
          } catch {
            DispatchQueue.main.async { result(FlutterError(code: "ocr", message: "Text recognition failed", details: nil)) }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
