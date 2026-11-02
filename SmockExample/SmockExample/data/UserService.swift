//
//  UserService.swift
//  SmockExample
//
//  Created by Dan Kane on 11/2/26.
//

import Smock

@Mockable
protocol UserService: Sendable {
    var cachedUserCount: Int { get }

    var isOfflineModeEnabled: Bool { get set }

    func fetchUsers() async throws -> [User]

    func getUser(id: Int) async throws -> User?

    func updateUser(id: Int, name: String) async throws -> Bool

    func deleteUser(_ id: Int) async throws

    func subscribeToUpdates(onUpdate: @escaping @Sendable ([User]) -> Void)
}
