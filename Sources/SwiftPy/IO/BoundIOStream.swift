//
//  BoundIOStream.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-02-23.
//

struct MultiIOStream: IOStream {
    let streams: [IOStream]
    
    func input(_ str: String) {
        for stream in streams {
            stream.input(str)
        }
    }
    
    func stdout(_ str: String) {
        for stream in streams {
            stream.stdout(str)
        }
    }
    
    func stderr(_ str: String) {
        for stream in streams {
            stream.stderr(str)
        }
    }
    
    func executionTime(_ time: UInt64) {
        for stream in streams {
            stream.executionTime(time)
        }
    }
}
