//
//  ContentView.swift
//  SmockExample
//
//  Created by Dan Kane on 7/5/26.
//

import SwiftUI

struct ContentView: View {
    @Binding var name: String

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, \(name)!")
        }
        .padding()
    }
}

#Preview {
    ContentView(name: .constant("Preview"))
}
