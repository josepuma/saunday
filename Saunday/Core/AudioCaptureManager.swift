import Foundation
import Observation
import ScreenCaptureKit
import Accelerate

// MARK: - Permission State

enum CapturePermissionState {
    case notDetermined
    case granted
    case denied
}

// MARK: - Audio Capture Manager

@Observable
final class AudioCaptureManager: NSObject {

    var permissionState: CapturePermissionState = .notDetermined
    var barMagnitudes: [Float] = Array(repeating: 0.001, count: 64)
    var isCapturing = false

    private var stream: SCStream?

    private let audioQueue = DispatchQueue(
        label: "cl.sayrin.saunday.audio",
        qos: .userInteractive
    )

    // FFT processor (solo accesible desde audioQueue)
    private let fftProcessor = FFTProcessor()

}

// MARK: - Permissions

extension AudioCaptureManager {

    func checkCurrentPermission() async {
        do {
            _ = try await SCShareableContent.current
            await MainActor.run {
                permissionState = .granted
            }
        } catch {
            await MainActor.run {
                permissionState = .notDetermined
            }
        }
    }

    func requestPermission() async {
        do {
            _ = try await SCShareableContent.current
            await MainActor.run {
                permissionState = .granted
            }
        } catch {
            await MainActor.run {
                permissionState = .denied
            }
        }
    }
}

// MARK: - Capture Control

extension AudioCaptureManager {

    func startCapture() async throws {

        let content = try await SCShareableContent.current

        guard let display = content.displays.first else {
            print("No display found")
            return
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()

        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true

        // video mínimo (necesario para stream)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        // audio
        config.sampleRate = 48000
        config.channelCount = 2

        let stream = SCStream(
            filter: filter,
            configuration: config,
            delegate: self
        )

        try stream.addStreamOutput(
            self,
            type: .audio,
            sampleHandlerQueue: audioQueue
        )

        try await stream.startCapture()

        self.stream = stream

        await MainActor.run {
            isCapturing = true
        }
    }

    func stopCapture() async {

        guard let stream else { return }

        try? await stream.stopCapture()

        self.stream = nil

        await MainActor.run {
            isCapturing = false
            barMagnitudes = Array(repeating: 0.001, count: 64)
        }
    }
}

// MARK: - Stream Output

extension AudioCaptureManager: SCStreamOutput {

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {

        guard type == .audio else { return }

        guard let mono = sampleBuffer.toMonoFloats() else { return }

        let bars = fftProcessor.process(mono)

        DispatchQueue.main.async { [weak self] in
            self?.barMagnitudes = bars
        }
    }
}

// MARK: - Stream Delegate

extension AudioCaptureManager: SCStreamDelegate {

    nonisolated func stream(
        _ stream: SCStream,
        didStopWithError error: Error
    ) {
        print("Stream stopped:", error)

        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = false
        }
    }
}

// MARK: - CMSampleBuffer → Mono Float

private extension CMSampleBuffer {

    func toMonoFloats() -> [Float]? {

        guard
            let desc = CMSampleBufferGetFormatDescription(self),
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
        else { return nil }

        let channels = Int(asbd.pointee.mChannelsPerFrame)
        let frameCount = CMSampleBufferGetNumSamples(self)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else {
            return nil
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == noErr, let ptr = dataPointer else {
            return nil
        }

        let floatPtr = ptr.withMemoryRebound(
            to: Float.self,
            capacity: length / MemoryLayout<Float>.size
        ) { $0 }

        var mono = [Float](repeating: 0, count: frameCount)

        if channels == 1 {

            for i in 0..<frameCount {
                mono[i] = floatPtr[i]
            }

        } else {

            for frame in 0..<frameCount {

                var sum: Float = 0

                for ch in 0..<channels {
                    sum += floatPtr[frame * channels + ch]
                }

                mono[frame] = sum / Float(channels)
            }
        }

        return mono
    }
}
