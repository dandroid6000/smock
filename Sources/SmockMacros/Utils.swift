//
//  Utils.swift
//  Smock
//
//  Created by Dan Kane on 6/30/26.
//

extension String {
    func trimmingWhitespaceByRegex() -> String {
        #if swift(>=6.0)
        replacing(/^\s+|\s+$/, with: "")
        #else
        replacing(try! Regex(#"^\s+|\s+$"#), with: "")
        #endif
    }
}
