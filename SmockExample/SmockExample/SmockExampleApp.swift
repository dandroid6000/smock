//
//  SmockExampleApp.swift
//  SmockExample
//
//  Created by Dan Kane on 7/5/26.
//

import SwiftUI

@main
struct SmockExampleApp: App {
    @State private var myService: MyService = MyServiceImpl()

    var body: some Scene {
        WindowGroup {
            ContentView(name: $myService.name)
        }
    }
}
