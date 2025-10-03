//
//  OverlayWindow.swift
//  subtitle
//
//  A borderless, click-through, always-on-top overlay window
//  that displays captions at the bottom of the screen system-wide.
//

import AppKit
import SwiftUI
import Combine

final class OverlayWindowController: NSWindowController {
    static let shared = OverlayWindowController()

    private var hosting: NSHostingView<OverlayCaptionView>?
    private var subscriptions = Set<AnyCancellable>()
    private var config = OverlayConfig()
    private let state = OverlayState()
    private weak var transcriberRef: CaptureTranscriber?
    private var bottomInset: CGFloat = 0

    private var panel: NSPanel? {
        return window as? NSPanel
    }

    func show(transcriber: CaptureTranscriber) {
        if window == nil {
            createWindow()
        }
        self.transcriberRef = transcriber

        let fixedWidth: CGFloat = config.fixedPixelWidth ?? ((NSScreen.main?.visibleFrame.width ?? 1280) * config.widthRatio)
        let view = OverlayCaptionView(transcriber: transcriber, state: state, config: config, fixedWidth: fixedWidth)
        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.hosting = hosting

        window?.contentView = hosting
        window?.isReleasedWhenClosed = false
        window?.orderFrontRegardless()

        // Reposition on text and screen changes
        transcriber.$currentOriginal
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fitAndPosition() }
            .store(in: &subscriptions)

        transcriber.$currentTranslated
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fitAndPosition() }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fitAndPosition() }
            .store(in: &subscriptions)

        // Initial position/size
        fitAndPosition()

        // Always allow dragging the bubble window
        setDragEnabled(true)
    }

    func hide() {
        subscriptions.removeAll()
        window?.orderOut(nil)
    }

    func setDragEnabled(_ enabled: Bool) {
        state.dragEnabled = enabled
        if let panel = self.panel {
            panel.ignoresMouseEvents = !enabled
            panel.isMovableByWindowBackground = enabled
        }
    }

    private func createWindow() {
        let screen = NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let initialFrame = NSRect(x: screenFrame.midX - 200, y: screenFrame.minY + 120, width: 400, height: 120)

        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = NSPanel(contentRect: initialFrame,
                            styleMask: style,
                            backing: .buffered,
                            defer: false)

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.delegate = self

        self.window = panel
    }

    private func fitAndPosition() {
        guard let window, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let fixedWidth: CGFloat = config.fixedPixelWidth ?? (visible.width * config.widthRatio)

        // Measure height for current text with fixed width
        let text: String = {
            if let t = transcriberRef?.currentTranslated, !t.isEmpty { return t }
            if let o = transcriberRef?.currentOriginal, !o.isEmpty { return o }
            return " "
        }()
        let height = measureBubbleHeight(text: text, fixedWidth: fixedWidth)

        if let hosting, let transcriber = transcriberRef {
            hosting.rootView = OverlayCaptionView(transcriber: transcriber, state: state, config: config, fixedWidth: fixedWidth)
            hosting.setFrameSize(NSSize(width: fixedWidth, height: height))
            hosting.layoutSubtreeIfNeeded()
        }

        let centerX = visible.minX + clamp(state.xRatio, 0.05, 0.95) * visible.width
        let centerY = visible.minY + clamp(state.yRatio, 0.05, 0.95) * visible.height
        let x = centerX - fixedWidth / 2
        let y = centerY - height / 2
        let newFrame = NSRect(x: x, y: y, width: fixedWidth, height: height)
        window.setFrame(newFrame, display: true)
        window.orderFrontRegardless()
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

    private func measureBubbleHeight(text: String, fixedWidth: CGFloat) -> CGFloat {
        let innerWidth = max(10, fixedWidth - config.horizontalPadding * 2)
        let font = NSFont.systemFont(ofSize: config.fontSize, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        let bounding = (text as NSString).boundingRect(
            with: NSSize(width: innerWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let lineHeight = ceil(font.boundingRectForFont.height + font.leading)
        let maxTextHeight = lineHeight * CGFloat(config.maxLines)
        let textHeight = min(ceil(bounding.height), ceil(maxTextHeight))
        let bubbleHeight = textHeight + config.verticalPadding * 2 + 14 // 额外留白，避免剪裁
        return max(40, bubbleHeight)
    }
}

extension OverlayWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let xr = (center.x - visible.minX) / visible.width
        let yr = (center.y - visible.minY) / visible.height
        state.xRatio = clamp(xr, 0.05, 0.95)
        state.yRatio = clamp(yr, 0.05, 0.95)
    }
}
