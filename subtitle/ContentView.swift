//
//  ContentView.swift
//  subtitle
//
//  Created by 许吉中 on 2025/10/3.
//

import SwiftUI
import Combine

@MainActor
final class ViewModel: ObservableObject {
    @Published var localeIdentifier: String = Locale.current.identifier
    @Published var autoScroll: Bool = true
    @Published var translationSource: String = "en" { // e.g. "en", "ja", "zh-Hans", etc.
        didSet {
            // 同步识别语言到所选源语言（常用映射）
            let mapped = Self.mapToSpeechLocale(from: translationSource)
            localeIdentifier = mapped
            Task { await TranslationService.shared.prepare(sourceIdentifier: translationSource, targetIdentifier: translationTarget) }
            // 如在运行，自动重启以应用切换
            if transcriber.isRunning {
                stop()
                start()
            }
        }
    }
    @Published var translationTarget: String = "zh-Hans" { // e.g. "zh-Hans", "en", "ja"
        didSet {
            Task { await TranslationService.shared.prepare(sourceIdentifier: translationSource, targetIdentifier: translationTarget) }
            if transcriber.isRunning {
                stop()
                start()
            }
        }
    }

    let transcriber = CaptureTranscriber()

    func start() {
        let locale = Locale(identifier: localeIdentifier)
        Task { await TranslationService.shared.prepare(sourceIdentifier: translationSource, targetIdentifier: translationTarget) }
        transcriber.start(locale: locale)
        OverlayWindowController.shared.show(transcriber: transcriber)
    }

    func stop() {
        transcriber.stop()
        OverlayWindowController.shared.hide()
    }

    private static func mapToSpeechLocale(from lang: String) -> String {
        switch lang {
        case "en": return "en-US"
        case "ja": return "ja-JP"
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        case "ko": return "ko-KR"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "es": return "es-ES"
        case "ru": return "ru-RU"
        case "it": return "it-IT"
        case "pt": return "pt-PT"
        default: return lang
        }
    }
}

struct ContentView: View {
    @StateObject private var vm: ViewModel
    @ObservedObject private var transcriber: CaptureTranscriber

    init() {
        let vm = ViewModel()
        _vm = StateObject(wrappedValue: vm)
        _transcriber = ObservedObject(wrappedValue: vm.transcriber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {

                Toggle("自动滚动", isOn: $vm.autoScroll)
                    .toggleStyle(.switch)

                Picker("识别语言", selection: $vm.translationSource) {
                    Text("英语").tag("en")
                    Text("日语").tag("ja")
                    Text("简体中文").tag("zh-Hans")
                    Text("繁体中文").tag("zh-Hant")
                    Text("韩语").tag("ko")
                    Text("法语").tag("fr")
                    Text("德语").tag("de")
                    Text("西班牙语").tag("es")
                    Text("俄语").tag("ru")
                    Text("意大利语").tag("it")
                    Text("葡萄牙语").tag("pt")
                }

                Picker("翻译为", selection: $vm.translationTarget) {
                    Text("简体中文").tag("zh-Hans")
                    Text("繁体中文").tag("zh-Hant")
                    Text("英语").tag("en")
                    Text("日语").tag("ja")
                    Text("韩语").tag("ko")
                    Text("法语").tag("fr")
                    Text("德语").tag("de")
                    Text("西班牙语").tag("es")
                    Text("俄语").tag("ru")
                    Text("意大利语").tag("it")
                    Text("葡萄牙语").tag("pt")
                }

                if transcriber.isRunning {
                    Button(role: .destructive) {
                        vm.stop()
                    } label: {
                        Label("停止", systemImage: "stop.circle")
                    }
                } else {
                    Button {
                        vm.start()
                    } label: {
                        Label("开始", systemImage: "play.circle")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                }
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(transcriber.logText.isEmpty ? "日志输出将显示在这里…\n首次使用会请求‘屏幕录制’和‘语音识别’权限。" : transcriber.logText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("bottom")
                }
                .background(Color(NSColor.textBackgroundColor))
                .onReceive(transcriber.$logText) { _ in
                    guard vm.autoScroll else { return }
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 420)
    }
}

#Preview {
    ContentView()
}
