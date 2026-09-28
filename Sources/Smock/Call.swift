//
//  Call.swift
//  Smock
//
//  Created by Dan Kane on 9/28/26.
//

#if DEBUG
/// Represents a member invocation, tracking when it occurred, what parameters were supplied (if any), and whether or not it has been verified.
struct Call: Sendable {
    let timestamp: ContinuousClock.Instant = ContinuousClock.now
    let params: [any Sendable]
    var isVerified: Bool = false

    func description(for signature: String) -> String {
        Call.description(for: signature, params: params)
    }

    static func description(for signature: String, params: [Any]? = nil) -> String {
        guard signature.contains("(") else {
            // Property
            return if let params, !params.isEmpty {
                ".\(signature) = \(params[0])"
            } else {
                ".\(signature)"
            }
        }

        // Method
        let split = signature.split(separator: "(", maxSplits: 1)
        guard
            let name = split.first,
            let paramString = split.last?.split(separator: ")", maxSplits: 1).first,
            !paramString.isEmpty
        else {
            return ".\(signature)"
        }

        let names = paramString.split(separator: ",").map { part in
            // e.g. "_ a: Int"
            String(part)
                .trimmingCharacters(in: .whitespaces)
                .split(separator: ":").first?
                .split(separator: " ").first ?? ""
        }

        let params = if let params {
            zip(names, params).map { name, param in
                if name == "_" {
                    "\(param)"
                } else {
                    "\(name): \(param)"
                }
            }.joined(separator: ", ")
        } else {
            // e.g. a:_:
            names.map { "\($0):" }.joined()
        }

        return ".\(name)(\(params))"
    }
}
#endif
