//
//  LogContainerView.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-03-05.
//

import SwiftUI

public struct LogContainerView<Content: View>: View {
    let tint: Color
    let content: () -> Content
    
    public init(
        tint: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.content = content
    }
    
    public var body: some View {
        HStack {
            Capsule()
                .fill(tint.gradient)
                .frame(width: 4)

            content()
        }
        .padding(4)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .background {
            tint.opacity(0.1)
        }
    }
}
