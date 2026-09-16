//
//  SmockTestSupport.swift
//  Smock
//
//  Created by Dan Kane on 6/18/26.
//

import Foundation
import Smock

#if DEBUG
#if canImport(XCTest)
import XCTest
#endif

#if canImport(Testing)
import Testing
#endif

// MARK: - XCTest Recorder

#if canImport(XCTest)
/// A ``TestRecorder`` for XCTest environments.
struct XCTestRecorder: TestRecorder, Sendable {
    init() {}

    func record(message: String, file: StaticString, line: UInt) {
        XCTFail(message, file: file, line: line)
    }
}
#endif

// MARK: - Swift Testing Recorder

#if canImport(Testing)
/// A ``TestRecorder`` for Swift Testing environments.
struct SwiftTestingRecorder: TestRecorder, Sendable {
    init() {}

    func record(message: String, file: StaticString, line: UInt) {
        // Swift Testing strictly requires 'fileID' to be non-empty and contain a forward slash "/".
        // We can safely synthesize a well-formed fileID from the file path.
        let filePath = String(describing: file)
        let components = filePath.split(separator: "/")
        let fileId = if components.count >= 2 {
            "\(components[components.count - 2])/\(components.last!)"
        } else {
            "Smock/Smock.swift" // Safe conforming fallback
        }
        let location = SourceLocation(
            fileID: fileId,
            filePath: filePath,
            line: Int(line) > 0 ? Int(line) : 1, // 0 is invalid
            column: 1
        )

        Issue.record(Comment(stringLiteral: message), sourceLocation: location)
    }
}
#endif

// MARK: - Auto-Configuration

public enum SmockTestSupport {

    /// Registers the standard XCTest and Swift Testing recorders.
    public static func initialize() {
        #if canImport(Testing)
        TestingBridge.register(SwiftTestingRecorder())
        #elseif canImport(XCTest)
        TestingBridge.register(XCTestRecorder())
        #endif
    }
}

/// A dynamic bridge class registered with the Objective-C runtime.
///
/// This class is searched for and instantiated reflectively by the core `Smock` base class.
@objc(SmockTestSupportAutoInitializer)
public final class SmockTestSupportAutoInitializer: NSObject {

    @objc public override init() {
        super.init()

        SmockTestSupport.initialize()
    }
}
#endif
