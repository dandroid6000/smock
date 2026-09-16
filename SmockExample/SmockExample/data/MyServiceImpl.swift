//
//  MyServiceImpl.swift
//  SmockExample
//
//  Created by Dan Kane on 7/8/26.
//

import Foundation

@Observable
class MyServiceImpl: MyService {
    var name: String = "My Service"

    func doSomething() {
        print("Hello, World!")
    }
}
