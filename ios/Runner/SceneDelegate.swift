import Flutter
import UIKit
import Vision
import WidgetKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    configureImportChannel()
    configureDetectionChannel()
    configureWidgetChannel()
    for item in connectionOptions.urlContexts { captureWidgetURL(item.url) }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for item in URLContexts { captureWidgetURL(item.url) }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func captureWidgetURL(_ url: URL) {
    guard url.scheme == "flourish", url.host == "widget",
      ["add", "template", "home"].contains(url.lastPathComponent) else { return }
    UserDefaults(suiteName: SharedImportStore.appGroupIdentifier)?.set(url.lastPathComponent, forKey: "widget_action")
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    FlutterMethodChannel(name: "flourish/widgets", binaryMessenger: controller.binaryMessenger)
      .invokeMethod("actionAvailable", arguments: nil)
  }

  private func configureWidgetChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    FlutterMethodChannel(name: "flourish/widgets", binaryMessenger: controller.binaryMessenger).setMethodCallHandler { call, result in
      let defaults = UserDefaults(suiteName: SharedImportStore.appGroupIdentifier)
      switch call.method {
      case "publish":
        guard let json = call.arguments as? String else { result(nil); return }
        defaults?.set(json, forKey: "widget_snapshot")
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      case "consumeAction":
        let action = defaults?.string(forKey: "widget_action")
        defaults?.removeObject(forKey: "widget_action")
        result(action)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `flourish/detection`: the payments queued by Shortcuts. iOS has no
  /// notification access to grant, so those calls are no-ops.
  private func configureDetectionChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "flourish/detection",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "peek":
        result(SharedImportStore.peekDetections())
      case "ack":
        SharedImportStore.ackDetections(call.arguments as? [String] ?? [])
        result(nil)
      case "isAccessGranted":
        result(true)
      case "openAccessSettings", "configure":
        result(nil)
      case "candidates":
        result([[String: Any]]())
      case "consumePendingRoute":
        result(SharedImportStore.consumePendingRoute())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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
          // Arabic and English alerts. Vision reads Arabic from iOS 16 (accurate
          // level only); older systems keep English.
          let wanted = ["ar-SA", "en-US"]
          let supported = (try? request.supportedRecognitionLanguages()) ?? []
          let languages = wanted.filter { supported.contains($0) }
          if !languages.isEmpty { request.recognitionLanguages = languages }
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
