//
//  AsyncSleep.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-31.
//

import Foundation
import SwiftUI

@Scriptable(base: .View)
@MainActor
public final class AsyncSleep {
    public let seconds: Double
    public internal(set) var startDate = Date()
    public let task: AsyncTask

    public init(seconds: Double) {
        self.seconds = seconds
        let seconds = seconds
        task = AsyncTask {
            try await Task.sleep(for: .seconds(seconds))
        }
        task.viewRepresentation = body()
    }

    func body() -> AnyView {
        let startDate = startDate
        let seconds = seconds
        return AnyView(erasing: LogContainerView(tint: .indigo) {
            TimelineView(.animation) { context in
                let interval = max(
                    0,
                    startDate
                        .addingTimeInterval(seconds)
                        .timeIntervalSince(context.date)
                )
                
                HStack {
                    Image(systemName: "clock")
                    
                    Text(
                        Date(timeIntervalSinceReferenceDate: interval),
                        format: .dateTime.minute().second()
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        })
    }
}

@available(macOS 14.0, iOS 17.0, *)
#Preview {
    @Previewable @State var sleep = AsyncSleep(seconds: 5)

    ScrollView {
        AsyncSleep(seconds: 3).body()
    }
}
