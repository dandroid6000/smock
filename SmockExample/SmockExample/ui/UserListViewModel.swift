//
//  UserListViewModel.swift
//  SmockExample
//
//  Created by Dan Kane on 11/2/26.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class UserListViewModel {
    private(set) var users: [User] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String? = nil

    private(set) var userCount: Int = 0

    // Inject the protocol here, NOT the concrete NetworkUserService
    private let userService: any UserService

    init(userService: any UserService) {
        self.userService = userService
        self.userCount = userService.cachedUserCount
    }

    func startSubscribing() {
        userService.subscribeToUpdates { [weak self] updatedUsers in
            Task { @MainActor in
                guard let self else { return }
                self.users = updatedUsers
                self.userCount = self.userService.cachedUserCount
            }
        }
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            users = try await userService.fetchUsers()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func renameUser(id: Int, newName: String) async {
        do {
            let success = try await userService.updateUser(id: id, name: newName)

            if success, let index = users.firstIndex(where: { $0.id == id }) {
                let oldUser = users[index]
                users[index] = User(id: oldUser.id, name: newName, email: oldUser.email)
            }
        } catch {
            errorMessage = "Failed to rename: \(error.localizedDescription)"
        }
    }

    func deleteUser(at offsets: IndexSet) async {
        let idsToDelete = offsets.map { users[$0].id }

        for id in idsToDelete {
            do {
                // 4. Calling a Void method with an unlabeled parameter
                try await userService.deleteUser(id)
                users.removeAll { $0.id == id }
                userCount = userService.cachedUserCount
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
            }
        }
    }
}
