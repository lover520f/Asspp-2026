//
//  QRCodeView.swift
//  Asspp
//
//  Created by GPT-5 Codex on 2025/11/06.
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct QRCodeView: View {
    private static let context = CIContext()

    let value: String
    var body: some View {
        Group {
            if let image = generateImage(from: value) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.2))
                    Image(systemName: "qrcode")
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(Text("QR code"))
    }

    private func generateImage(from string: String) -> UIImage? {
        guard !string.isEmpty else { return nil }
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let scaleTransform = CGAffineTransform(scaleX: 12, y: 12)
        let scaledImage = outputImage.transformed(by: scaleTransform)
        guard let cgImage = QRCodeView.context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
