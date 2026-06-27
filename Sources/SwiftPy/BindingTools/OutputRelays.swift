//
//  OutputRelays.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-04-29.
//

import Foundation

@MainActor
class OutputRelayHandler {
    let pipe = Pipe()
    let stream: Int32
    let lastStream: Int32

    init(stream: Int32, output: @escaping @Sendable (String) -> Void) {
        fflush(nil)
        let lastStream = dup(stream)
        self.stream = stream
        self.lastStream = lastStream

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            _ = data.withUnsafeBytes { buffer in
                Darwin.write(lastStream, buffer.baseAddress, buffer.count)
            }

            // `String(decoding:as:)` substitutes U+FFFD for invalid bytes
            // instead of returning nil, so a multibyte character split across
            // two pipe reads garbles only the seam rather than dropping the
            // whole chunk.
            output(String(decoding: data, as: UTF8.self))
        }

        dup2(pipe.fileHandleForWriting.fileDescriptor, stream)
    }

    deinit {
        pipe.fileHandleForReading.readabilityHandler = nil
        dup2(lastStream, stream)
        close(lastStream)
        pipe.fileHandleForWriting.closeFile()
        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remaining.isEmpty {
            _ = remaining.withUnsafeBytes { buffer in
                Darwin.write(stream, buffer.baseAddress, buffer.count)
            }
        }
    }
}

@MainActor
public struct OutputRelays {
    let outputRelayHandler: OutputRelayHandler
    let errorRelayHandler: OutputRelayHandler

    init(interpreter: Interpreter, filterOSLog: Bool = true) {
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)

        let connection = interpreter.connection
        
        outputRelayHandler = OutputRelayHandler(stream: STDOUT_FILENO) { value in
            connection.send(id: 0, .stdout(text: value))
        }

        errorRelayHandler = OutputRelayHandler(stream: STDERR_FILENO) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if filterOSLog, trimmed.hasPrefix("OSLOG") {
                return
            }
            connection.send(id: 0, .stderr(text: value))
        }
    }
}
