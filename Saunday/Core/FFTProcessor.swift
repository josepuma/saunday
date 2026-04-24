//
//  FFTProcessor.swift
//  macapp
//
//  Created by José Puma on 23-04-26.
//

import Accelerate

final class FFTProcessor {

    private let fftSize = 2048
    private let log2n: vDSP_Length = 11

    private var window: [Float]
    private var mono: [Float]

    private var real: [Float]
    private var imag: [Float]
    private var magnitudes: [Float]

    private var output: [Float]

    private let fftSetup: FFTSetup

    private let bands: [(Int, Int)]

    init() {

        window = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningDenormalized,
            count: fftSize,
            isHalfWindow: false
        )

        mono = [Float](repeating: 0, count: fftSize)

        real = [Float](repeating: 0, count: fftSize/2)
        imag = [Float](repeating: 0, count: fftSize/2)
        magnitudes = [Float](repeating: 0, count: fftSize/2)

        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        // bandas logarítmicas
        let binHz = 48000.0 / Double(fftSize)

        let freqLo = 80.0
        let freqHi = 15000.0
        let count = 64

        let logLo = log(freqLo)
        let logHi = log(freqHi)

        var b: [(Int,Int)] = []

        for i in 0..<count {

            let f0 = exp(logLo + Double(i)/Double(count)*(logHi-logLo))
            let f1 = exp(logLo + Double(i+1)/Double(count)*(logHi-logLo))

            let lo = max(1, Int(f0/binHz))
            let hi = max(lo+1, Int(f1/binHz))

            b.append((lo, min(hi, fftSize/2 - 1)))
        }

        bands = b
        output = [Float](repeating: 0, count: bands.count)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func process(_ input: [Float]) -> [Float] {

        mono.withUnsafeMutableBufferPointer { ptr in
            ptr.initialize(repeating: 0)
        }

        let count = min(input.count, fftSize)
        mono.replaceSubrange(0..<count, with: input[0..<count])

        vDSP.multiply(mono, window, result: &mono)

        mono.withUnsafeBufferPointer { monoPtr in
            real.withUnsafeMutableBufferPointer { rPtr in
                imag.withUnsafeMutableBufferPointer { iPtr in

                    var split = DSPSplitComplex(
                        realp: rPtr.baseAddress!,
                        imagp: iPtr.baseAddress!
                    )

                    monoPtr.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: fftSize/2
                    ) { complexPtr in

                        vDSP_ctoz(
                            complexPtr,
                            2,
                            &split,
                            1,
                            vDSP_Length(fftSize/2)
                        )
                    }

                    vDSP_fft_zrip(
                        fftSetup,
                        &split,
                        1,
                        log2n,
                        FFTDirection(FFT_FORWARD)
                    )
                }
            }
        }

        real.withUnsafeMutableBufferPointer { rPtr in
            imag.withUnsafeMutableBufferPointer { iPtr in

                var split = DSPSplitComplex(
                    realp: rPtr.baseAddress!,
                    imagp: iPtr.baseAddress!
                )

                vDSP_zvmags(
                    &split,
                    1,
                    &magnitudes,
                    1,
                    vDSP_Length(fftSize/2)
                )
            }
        }

        let scale = 1.0 / Float(fftSize)

        for (index, band) in bands.enumerated() {

            let (lo, hi) = band

            var sum: Float = 0

            for i in lo..<hi {
                sum += magnitudes[i]
            }

            let avg = (sum / Float(hi-lo)) * scale * scale
            let rms = sqrt(avg)

            let dB = 20 * log10(max(rms, 1e-9))

            output[index] = max(0, min(1, (dB + 60) / 55))
        }

        return output
    }
}
