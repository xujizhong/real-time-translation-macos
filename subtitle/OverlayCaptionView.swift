//
//  OverlayCaptionView.swift
//  subtitle
//
//  Renders a minimal YouTube-style caption bubble.
//

import SwiftUI

struct OverlayConfig {
    var maxLines: Int = 2
    var fontSize: CGFloat = 28
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 10
    var cornerRadius: CGFloat = 10
    var backgroundOpacity: CGFloat = 0.65
    var widthRatio: CGFloat = 0.8 // legacy ratio (unused when fixedPixelWidth != nil)
    var fixedPixelWidth: CGFloat? = 800 // 固定像素宽度，优先于比例
}

struct OverlayCaptionView: View {
    @ObservedObject var transcriber: CaptureTranscriber
    @ObservedObject var state: OverlayState
    var config: OverlayConfig
    var fixedWidth: CGFloat

    private var captionText: String {
        let text = transcriber.currentTranslated.isEmpty ? transcriber.currentOriginal : transcriber.currentTranslated
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if captionText.isEmpty {
                Color.clear.frame(width: 1, height: 1)
            } else {
                captionBubble(text: captionText)
                    .frame(width: fixedWidth)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func captionBubble(text: String) -> some View {
        Text(text)
            .font(.system(size: config.fontSize, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(config.maxLines)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 0)
            .padding(.horizontal, config.horizontalPadding)
            .padding(.vertical, config.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: config.cornerRadius)
                    .fill(Color.black.opacity(config.backgroundOpacity))
            )
    }

}
