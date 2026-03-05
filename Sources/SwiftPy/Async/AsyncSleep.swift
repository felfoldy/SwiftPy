//
//  AsyncSleep.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-31.
//

import Foundation
import SwiftUI

@MainActor
@Scriptable
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

        task.viewRepresentation = representation
    }
}

extension AsyncSleep: ViewRepresentable {
    public struct Content: RepresentationContent {
        @State public var model: AsyncSleep
        
        public init(model: AsyncSleep) {
            self.model = model
        }

        public var body: some View {
            LogContainerView(tint: .indigo) {
                TimelineView(.animation) { context in
                    let interval = max(
                        0,
                        model.startDate
                            .addingTimeInterval(model.seconds)
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
            }
        }
    }
}

@available(macOS 14.0, iOS 17.0, *)
#Preview {
    @Previewable @State var sleep = AsyncSleep(seconds: 5)

    ScrollView {
        AsyncSleep.Content(model: sleep)
            .frame(maxWidth: .infinity)
    }
}
