import Flutter
import AVFoundation
import CryptoKit
import Foundation
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    MaxeiFolderMediaImporter.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "MaxeiFolderMediaImporter")
    )
    MaxeiMediaArtworkPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "MaxeiMediaArtworkPlugin")
    )
  }
}

private final class MaxeiMediaArtworkPlugin: NSObject, FlutterPlugin {
  private static let channelName = "app.maxei/media_artwork"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(MaxeiMediaArtworkPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getArtwork",
          let arguments = call.arguments as? [String: Any],
          let rawURI = arguments["uri"] as? String,
          let kind = arguments["kind"] as? String,
          kind == "audio" || kind == "video",
          let url = URL(string: rawURI),
          url.isFileURL else {
      result(
        FlutterError(
          code: "invalid_artwork_request",
          message: "URI ou type de média invalide.",
          details: nil
        )
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let artwork = try Self.extractArtwork(from: url, kind: kind)
        DispatchQueue.main.async {
          result(artwork)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "artwork_unavailable",
              message: "Impossible d’extraire l’image de ce média.",
              details: error.localizedDescription
            )
          )
        }
      }
    }
  }

  private static func extractArtwork(from url: URL, kind: String) throws -> Data? {
    let asset = AVURLAsset(url: url)
    if kind == "audio",
       let metadata = asset.commonMetadata.first(where: {
         $0.commonKey == .commonKeyArtwork
       }),
       let artwork = metadata.dataValue,
       let image = UIImage(data: artwork) {
      return image.jpegData(compressionQuality: 0.82)
    }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 640, height: 640)
    let frame = try generator.copyCGImage(
      at: CMTime(seconds: 0.1, preferredTimescale: 600),
      actualTime: nil
    )
    return UIImage(cgImage: frame).jpegData(compressionQuality: 0.82)
  }
}

private final class MaxeiFolderMediaImporter: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private static let channelName = "app.maxei/ios_folder_media_import"
  private static let audioExtensions: Set<String> = [
    "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "aiff", "wma",
  ]
  private static let videoExtensions: Set<String> = [
    "mp4", "m4v", "mov", "mkv", "webm", "avi", "3gp", "mpeg", "mpg",
  ]

  private let presenter: UIViewController?
  private var pendingResult: FlutterResult?

  private init(presenter: UIViewController?) {
    self.presenter = presenter
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = MaxeiFolderMediaImporter(presenter: registrar.viewController)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "importFolder" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "import_in_progress",
          message: "Un import de dossier est déjà en cours.",
          details: nil
        )
      )
      return
    }
    guard let presenter else {
      result(
        FlutterError(
          code: "picker_unavailable",
          message: "Le sélecteur de dossiers n’est pas disponible.",
          details: nil
        )
      )
      return
    }

    pendingResult = result
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [.folder],
      asCopy: false
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(result: [])
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let folderURL = urls.first else {
      finish(result: [])
      return
    }

    let didStartAccessing = folderURL.startAccessingSecurityScopedResource()
    DispatchQueue.global(qos: .userInitiated).async {
      defer {
        if didStartAccessing {
          folderURL.stopAccessingSecurityScopedResource()
        }
      }

      do {
        let items = try Self.copyMedia(from: folderURL)
        DispatchQueue.main.async {
          self.finish(result: items)
        }
      } catch {
        DispatchQueue.main.async {
          self.finish(
            error: FlutterError(
              code: "folder_import_failed",
              message: "Le dossier média n’a pas pu être importé.",
              details: error.localizedDescription
            )
          )
        }
      }
    }
  }

  private static func copyMedia(from sourceFolder: URL) throws -> [[String: Any]] {
    let fileManager = FileManager.default
    var enumerationError: Error?
    guard let enumerator = fileManager.enumerator(
      at: sourceFolder,
      includingPropertiesForKeys: [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .contentModificationDateKey,
      ],
      options: [.skipsHiddenFiles, .skipsPackageDescendants],
      errorHandler: { _, error in
        enumerationError = error
        return false
      }
    ) else {
      throw NSError(
        domain: "MaxeiFolderMediaImporter",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Impossible de lire le dossier choisi."]
      )
    }

    let supportDirectory = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let folderKey = SHA256.hash(data: Data(sourceFolder.standardizedFileURL.path.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    let destinationRoot = supportDirectory
      .appendingPathComponent("Maxei", isDirectory: true)
      .appendingPathComponent("ImportedMedia", isDirectory: true)
      .appendingPathComponent(folderKey, isDirectory: true)
    try fileManager.createDirectory(
      at: destinationRoot,
      withIntermediateDirectories: true
    )

    var imported: [[String: Any]] = []
    var createdFiles: [URL] = []
    do {
      for case let sourceURL as URL in enumerator {
        let values = try sourceURL.resourceValues(forKeys: [
          .isDirectoryKey,
          .isRegularFileKey,
          .isSymbolicLinkKey,
          .fileSizeKey,
          .contentModificationDateKey,
        ])
        if values.isDirectory == true || values.isSymbolicLink == true ||
            values.isRegularFile != true {
          continue
        }

        let ext = sourceURL.pathExtension.lowercased()
        let kind: String
        if audioExtensions.contains(ext) {
          kind = "audio"
        } else if videoExtensions.contains(ext) {
          kind = "video"
        } else {
          continue
        }

        let sourcePath = sourceURL.standardizedFileURL.path
        let rootPath = sourceFolder.standardizedFileURL.path
        guard sourcePath.hasPrefix(rootPath + "/") else {
          throw NSError(
            domain: "MaxeiFolderMediaImporter",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Un fichier sort du dossier sélectionné."]
          )
        }
        let relativePath = String(sourcePath.dropFirst(rootPath.count + 1))
        let destinationURL = relativePath
          .split(separator: "/")
          .reduce(destinationRoot) { parent, component in
            parent.appendingPathComponent(String(component))
          }
        try fileManager.createDirectory(
          at: destinationURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )

        if !fileManager.fileExists(atPath: destinationURL.path) {
          try fileManager.copyItem(at: sourceURL, to: destinationURL)
          createdFiles.append(destinationURL)
        }
        let destinationValues = try destinationURL.resourceValues(forKeys: [.fileSizeKey])
        imported.append([
          "name": destinationURL.lastPathComponent,
          "path": destinationURL.path,
          "kind": kind,
          "size": destinationValues.fileSize ?? values.fileSize ?? 0,
          "addedAtMs": Int64(
            (values.contentModificationDate ?? Date()).timeIntervalSince1970 * 1000
          ),
        ])
      }

      if let error = enumerationError {
        throw error
      }
    } catch {
      for fileURL in createdFiles.reversed() {
        try? fileManager.removeItem(at: fileURL)
      }
      throw error
    }
    return imported
  }

  private func finish(result value: Any?) {
    let callback = pendingResult
    pendingResult = nil
    callback?(value)
  }

  private func finish(error: FlutterError) {
    let callback = pendingResult
    pendingResult = nil
    callback?(error)
  }
}
