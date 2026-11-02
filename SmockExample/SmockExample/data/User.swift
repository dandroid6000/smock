//
//  User.swift
//  SmockExample
//
//  Created by Dan Kane on 11/2/26.
//

struct User: Decodable, Equatable, Identifiable, Sendable {
    let id: Int
    let name: String
    let email: String
}
