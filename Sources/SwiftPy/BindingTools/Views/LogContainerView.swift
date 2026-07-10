//
//  LogContainerView.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-03-05.
//

import SwiftUI

public struct LogContainerView<Content: View>: View {
    let tint: Color
    let title: String?
    let icon: String?
    let content: () -> Content

    public init(
        tint: Color,
        title: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.title = title
        self.icon = icon
        self.content = content
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Capsule()
                .fill(tint.gradient)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    HStack(spacing: 4) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.caption2)
                                .foregroundStyle(tint)
                        }
                        Text(title)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(tint)
                        Spacer()
                    }
                }
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(tint.opacity(0.1))
                .shadow(radius: 4)
        }
        .padding(4)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            LogContainerView(tint: .blue, title: "Thought", icon: "brain") {
                Text("I should print the requested text using the print_content tool.")
                    .font(.caption)
            }
            LogContainerView(tint: .orange, title: #"greet(name="Bob")"#, icon: "wrench.and.screwdriver") {
                Text("greeted")
                    .font(.caption.monospaced())
            }
            LogContainerView(tint: .green, title: "Tool output") {
                Text("success")
                    .font(.caption)
            }
            LogContainerView(tint: .teal, title: "Final answer", icon: "checkmark.circle") {
                Text("The text \"Print to the console\" has been printed to the console.")
                    .font(.caption)
            }
            LogContainerView(tint: .gray) {
                Text("Print to the console")
                    .font(.caption.monospaced())
            }
        }
        .padding()
    }
    .background(.black)
}
