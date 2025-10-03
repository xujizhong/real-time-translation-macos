//
//  CaptureTranscriber.swift
//  subtitle
//
//  Created by Codex on 2025/10/3.
//

import Foundation
import Combine
import ScreenCaptureKit
import Speech
import AVFoundation

final class CaptureTranscriber: NSObject, ObservableObject {
    @Published var isRunning: Bool = false
    @Published var logText: String = ""
    @Published var translatedLogText: String = ""
    // 当前正在展示的一句（增量更新，不追加日志）
    @Published var currentOriginal: String = ""
    @Published var currentTranslated: String = ""

    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "capture.audio.queue")

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var lastPrintedText: String = ""
    private var lastTranslatedSource: String = ""
    private var lastDisplayedSentence: String = ""

    func start(locale: Locale = Locale.current) {
        guard !isRunning else { return }

        Task { [weak self] in
            guard let self else { return }

            // 1) Ask Speech permission first to fail fast
            let speechAuthorized = await Self.requestSpeechAuthorization()
            guard speechAuthorized else {
                self.appendLog("[错误] 语音识别未授权。请在系统设置 > 隐私与安全性 > 语音识别中授权。")
                return
            }

            self.setupRecognizer(locale: locale)

            do {
                try await self.startCaptureAndTranscribe()
                DispatchQueue.main.async { self.isRunning = true }
                self.appendLog("[信息] 已开始捕获系统音频并转写…")
            } catch {
                self.appendLog("[错误] 启动失败: \(error.localizedDescription)")
                self.stop()
            }
        }
    }

    func stop() {
        if let recognitionRequest {
            recognitionRequest.endAudio()
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                try await stream?.stopCapture()
            } catch {
                appendLog("[警告] 停止采集出错: \(error.localizedDescription)")
            }
            stream = nil
            DispatchQueue.main.async { self.isRunning = false }
            appendLog("[信息] 已停止。")
        }
    }

    private func setupRecognizer(locale: Locale) {
        let recognizer = SFSpeechRecognizer(locale: locale)
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.recognitionRequest = request

        self.recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.appendLog("[错误] 识别任务: \(error.localizedDescription)")
                return
            }
            guard let result else { return }

            let sentence = self.latestSentence(from: result)
            if !sentence.isEmpty, sentence != self.lastDisplayedSentence {
                self.lastDisplayedSentence = sentence
                DispatchQueue.main.async { self.currentOriginal = sentence }
                if sentence != self.lastTranslatedSource {
                    self.lastTranslatedSource = sentence
                    Task {
                        let cn = await TranslationService.shared.translate(sentence)
                        DispatchQueue.main.async { self.currentTranslated = cn }
                    }
                }
            }
            if result.isFinal {
                // 最终结果：仅把最后一句写入日志一次
                let finalText = self.lastDisplayedSentence.isEmpty ? self.latestSentence(from: result) : self.lastDisplayedSentence
                if !finalText.isEmpty {
                    self.appendLog(finalText)
                    Task {
                        let cn = await TranslationService.shared.translate(finalText)
                        if !cn.isEmpty { self.appendTranslation(cn) }
                    }
                }
                self.lastPrintedText = ""
                self.lastDisplayedSentence = ""
            }
        }
    }

    private func latestSentence(from result: SFSpeechRecognitionResult) -> String {
        let fullString = result.bestTranscription.formattedString
        let full = fullString as NSString
        let segments = result.bestTranscription.segments
        guard !segments.isEmpty else {
            return fullString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let enders = CharacterSet(charactersIn: ".?!。？！…！？")
        var lastBoundaryLocation: Int = -1
        for i in 0..<(segments.count - 1) {
            let seg = segments[i]
            let segRange = seg.substringRange
            let segText = full.substring(with: segRange)
            let end = seg.timestamp + seg.duration
            let nextStart = segments[i + 1].timestamp
            let gap = nextStart - end
            if segText.unicodeScalars.last.map({ enders.contains($0) }) == true || gap >= 0.6 {
                lastBoundaryLocation = segRange.location + segRange.length
            }
        }

        if lastBoundaryLocation >= 0 {
            let tailRange = NSRange(location: lastBoundaryLocation, length: max(0, full.length - lastBoundaryLocation))
            return full.substring(with: tailRange).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: if没有检测到句边界，取结尾的若干 segment，避免从头展示
        let maxChars = 160
        let maxSegments = 20
        var startLoc = full.length
        var charCount = 0
        var used = 0
        var idx = segments.count - 1
        while idx >= 0 && used < maxSegments && charCount < maxChars {
            let r = segments[idx].substringRange
            startLoc = r.location
            charCount += r.length
            used += 1
            idx -= 1
        }
        let len = max(0, full.length - startLoc)
        let tail = full.substring(with: NSRange(location: startLoc, length: len))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return tail
    }

    private func startCaptureAndTranscribe() async throws {
        // 2) 选择一个显示器进行捕获（包含其应用音频）
        // 系统会自动处理“屏幕录制”权限弹窗
        let content = try await SCShareableContent.current
        guard let display = content.displays.first ?? content.displays.first else {
            throw NSError(domain: "CaptureTranscriber", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到可用显示器"])
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        // 仅关心音频，视频降到最小负载
        config.width = 8
        config.height = 8
        config.showsCursor = false
        config.capturesAudio = true
        // 建议采样率和声道数，Speech 会自行重采样，但给出常见参数有助于兼容
        config.sampleRate = 48_000
        config.channelCount = 1
        // 排除自身应用音频，避免回声
        config.excludesCurrentProcessAudio = true

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        // 附加屏幕与音频两个输出；屏幕帧会被忽略，只为避免“没有对应输出”警告
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
    }

    private func appendLog(_ line: String) {
        print(line)
        DispatchQueue.main.async {
            self.logText.append((self.logText.isEmpty ? "" : "\n") + line)
        }
    }

    private func appendTranslation(_ line: String) {
        print("译: \(line)")
        DispatchQueue.main.async {
            self.translatedLogText.append((self.translatedLogText.isEmpty ? "" : "\n") + line)
            // 同步到总日志中，便于主界面查看
            self.logText.append("\n译: " + line)
        }
    }

    private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

// MARK: - SCStreamOutput / SCStreamDelegate

extension CaptureTranscriber: SCStreamOutput, SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
        // 将系统音频帧直接送入语音识别请求
        if let request = recognitionRequest {
            request.appendAudioSampleBuffer(sampleBuffer)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        appendLog("[错误] 音频流停止: \(error.localizedDescription)")
        stop()
    }
}
