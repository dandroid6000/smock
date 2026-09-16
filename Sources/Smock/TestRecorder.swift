//
//  TestRecorder.swift
//  Smock
//
//  Created by Dan Kane on 6/18/26.
//

/// An interface for test frameworks to receive and record verification failures.
public protocol TestRecorder: Sendable {
    /// Records a verification failure at the original call site.
    func record(message: String, file: StaticString, line: UInt)
}
