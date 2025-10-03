//
//  TranslationService.swift
//  subtitle
//

import Foundation

#if canImport(Translation)
import Translation
#endif

final class TranslationService {
    static let shared = TranslationService()

    #if canImport(Translation)
    @available(macOS 15.0, *)
    private let availability = LanguageAvailability()

    @available(macOS 15.0, *)
    private var session: TranslationSession?

    @available(macOS 15.0, *)
    private var currentSource = Locale.Language(identifier: "en")
    @available(macOS 15.0, *)
    private var currentTarget = Locale.Language(identifier: "zh-Hans")
    #endif

    // 准备：源语言(sourceIdentifier) -> 目标语言(targetIdentifier)
    func prepare(sourceIdentifier: String, targetIdentifier: String) async {
        #if canImport(Translation)
        guard #available(macOS 15.0, *) else { return }
        do {
            let target = Locale.Language(identifier: targetIdentifier)
            let src = Locale.Language(identifier: sourceIdentifier)
            self.currentSource = src
            self.currentTarget = target
            self.session = nil
            let status = await availability.status(from: src, to: target)
            switch status {
            case .unsupported:
                print("[Translation] Unsupported pair: \(sourceIdentifier)->\(targetIdentifier)")
                session = nil
                return
            default:
                break
            }
            let s = TranslationSession(installedSource: src, target: target)
            try await s.prepareTranslation()
            self.session = s
        } catch {
            print("[Translation] prepare error: \(error)")
        }
        #endif
    }

    // 翻译到当前已准备的目标语言
    func translate(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        #if canImport(Translation)
        guard #available(macOS 15.0, *) else { return text }
        do {
            if session == nil {
                // 懒加载：按当前 source/target
                let s = TranslationSession(installedSource: currentSource, target: currentTarget)
                try await s.prepareTranslation()
                self.session = s
            }
            guard let s = session else { return text }
            let response = try await s.translate(trimmed)
            return response.targetText
        } catch {
            print("[Translation] translate error: \(error)")
            return text
        }
        #else
        return text
        #endif
    }
}
