//
//  StdOutputRelayIOStream.swift
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
    
    init(stream: Int32, output: @escaping @MainActor (String) -> Void) {
        let lastStream = dup(stream)
        self.stream = stream
        self.lastStream = lastStream
        
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            
            _ = data.withUnsafeBytes { buffer in
                Darwin.write(lastStream, buffer.baseAddress, buffer.count)
            }
            
            if let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    output(str)
                }
            }
        }
        
        dup2(pipe.fileHandleForWriting.fileDescriptor, stream)
    }
    
    deinit {
        dup2(lastStream, stream)
        close(lastStream)
    }
}

@MainActor
public struct OutputRelays {
    let outputRelayHandler: OutputRelayHandler
    let errorRelayHandler: OutputRelayHandler

    init(filterOSLog: Bool = true) {
        outputRelayHandler = OutputRelayHandler(stream: STDOUT_FILENO) { value in
            Interpreter.output.stdout(value)
        }
        
        errorRelayHandler = OutputRelayHandler(stream: STDERR_FILENO) { value in
            if filterOSLog, value.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("OSLOG") {
                return
            }
            Interpreter.output.stderr(value)
        }
    }
}
