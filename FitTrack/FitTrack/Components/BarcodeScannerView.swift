import SwiftUI
import Vision
import VisionKit

/// Live-Kamera-Scanner für Lebensmittel-Barcodes (VisionKit, ab iPhone XS / iOS 16).
/// Meldet jeden neu erkannten Barcode einmal über `onScan`.
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    /// `false` im Simulator und auf Geräten ohne Neural Engine.
    static var isSupported: Bool { DataScannerViewController.isSupported }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .itf14, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        // Scannen erst starten, wenn der Controller im Fenster hängt.
        DispatchQueue.main.async {
            if !scanner.isScanning {
                try? scanner.startScanning()
            }
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        private var lastCode: String?

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            report([item])
        }

        private func report(_ items: [RecognizedItem]) {
            for item in items {
                guard case .barcode(let barcode) = item,
                      let value = barcode.payloadStringValue?.trimmingCharacters(in: .whitespaces),
                      !value.isEmpty,
                      value != lastCode
                else { continue }
                lastCode = value
                onScan(value)
                return
            }
        }
    }
}
