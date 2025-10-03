//
//  OverlayState.swift
//  subtitle
//

import AppKit
import Combine

final class OverlayState: ObservableObject {
    @Published var dragEnabled: Bool = false
    // Normalized position (0..1) in screen coordinates, from bottom-left origin
    @Published var xRatio: CGFloat = 0.5
    @Published var yRatio: CGFloat = 0.12
}

