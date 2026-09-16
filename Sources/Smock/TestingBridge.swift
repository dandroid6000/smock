//
//  TestingBridge.swift
//  Smock
//
//  Created by Dan Kane on 6/18/26.
//

#if swift(>=6.0)
import Synchronization
#else
// Fallback to swift-mutex implementation
import Mutex
#endif

#if DEBUG
///// A dynamic, zero-dependency bridge to record verification failures across testing frameworks.
public enum TestingBridge {
    private static let activeRecorders = Mutex<[any TestRecorder]>([])

    /// Registers a concrete failure recorder for an environment.
    public static func register<T: TestRecorder>(_ recorder: T) {
        activeRecorders.withLock { recorders in
            guard !recorders.contains(where: { $0 is T }) else {
                print("Skipping registration of recorder: \(T.self) — already registered")
                return
            }
            print("Registering recorder: \(T.self)")
            recorders.append(recorder)
        }
    }

    /// Records a test verification failure across all registered environments.
    ///
    /// If no dynamic test environments have been registered, it falls back to a safe console output.
    public static func record(_ message: String, file: StaticString, line: UInt) {
        let recorders = activeRecorders.withLock { $0 }

        guard !recorders.isEmpty else {
            print("⚠️ [Smock Warning]: Verification failed but no test framework recorders were registered.")
            print("❌ [Smock Failure]: \(message) at \(file):\(line)")
//            assertionFailure(message)
            return
        }

        recorders.forEach {
            $0.record(message: message, file: file, line: line)
        }
    }
}
#endif
