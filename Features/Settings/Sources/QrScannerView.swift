import AVFoundation
import SwiftUI
import VisionKit

/// B-b의 QR 읽기 영역 (D-044). 띄우기 전에 `requestAccess()`로 카메라를 쓸 수 있는지 본다
struct QrScannerView: UIViewControllerRepresentable {
  /// 읽은 QR 내용. 받아들였으면 true를 돌려주고, 그 뒤로는 스캔을 멈춘다
  let onScanned: (String) -> Bool
  /// 스캔 중 카메라를 잃음(다른 앱이 가져감 등)
  let onUnavailable: () -> Void

  /// 카메라 권한을 묻고, 이 기기에서 QR을 읽을 수 있는지 돌려준다. 시뮬레이터는 항상 false
  static func requestAccess() async -> Bool {
    guard DataScannerViewController.isSupported else { return false }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: break
    case .notDetermined:
      guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
    default: return false
    }
    return DataScannerViewController.isAvailable
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIViewController(context: Context) -> DataScannerViewController {
    let scanner = DataScannerViewController(
      recognizedDataTypes: [.barcode(symbologies: [.qr])],
      recognizesMultipleItems: false,
      isHighlightingEnabled: true
    )
    scanner.delegate = context.coordinator
    return scanner
  }

  func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
    context.coordinator.parent = self
    guard !context.coordinator.accepted, !scanner.isScanning else { return }
    do {
      try scanner.startScanning()
    } catch {
      // 화면 갱신 중에 상태를 바꾸지 않도록 다음 차례로 미룬다
      Task { onUnavailable() }
    }
  }

  static func dismantleUIViewController(
    _ scanner: DataScannerViewController, coordinator: Coordinator
  ) {
    scanner.stopScanning()
  }

  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    var parent: QrScannerView
    /// 카메라는 QR이 보이는 동안 계속 알리므로 받아들인 뒤로는 무시한다
    var accepted = false

    init(parent: QrScannerView) {
      self.parent = parent
    }

    func dataScanner(
      _ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
      allItems: [RecognizedItem]
    ) {
      for case .barcode(let barcode) in addedItems {
        guard !accepted, let payload = barcode.payloadStringValue else { continue }
        if parent.onScanned(payload) {
          accepted = true
          dataScanner.stopScanning()
        }
      }
    }

    func dataScanner(
      _ dataScanner: DataScannerViewController,
      becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
    ) {
      parent.onUnavailable()
    }
  }
}
