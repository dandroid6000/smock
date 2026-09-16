//
//  MyService.swift
//  SmockExample
//
//  Created by Dan Kane on 7/8/26.
//

import Smock
import Foundation

@Mockable
protocol MyService: AnyObject, Observable {
    var name: String { get set }

    func doSomething()
}
