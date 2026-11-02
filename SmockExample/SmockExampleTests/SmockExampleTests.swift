//
//  SmockExampleTests.swift
//  SmockExampleTests
//
//  Created by Dan Kane on 7/5/26.
//

import Foundation
import Smock
import Testing
@testable import SmockExample

enum TestError: LocalizedError {
    case testError

    var errorDescription: String? {
        "\(self)"
    }
}

@MainActor
class SmockExampleTests {

    private let userServiceMock = UserServiceMock()
    private var viewModel: UserListViewModel!

    init() {
        // Invoked on view model init
        when(userServiceMock).cachedUserCount.then(return: 0)

        viewModel = UserListViewModel(userService: userServiceMock)
    }

    @Test
    func `init sets user count`() async throws {
        when(userServiceMock).cachedUserCount.then(return: 1)

        let viewModel = UserListViewModel(userService: userServiceMock)

        #expect(viewModel.userCount == 1)
        verify(userServiceMock).cachedUserCount.wasRead()
    }

    @Test
    func `startSubscribing adds callback`() async throws {
        let userList = [
            User(id: 0, name: "A", email: "a@b.com"),
            User(id: 1, name: "B", email: "b@c.com"),
            User(id: 2, name: "C", email: "c@d.com")
        ]

        // Invoke the closure to verify handling
        when(userServiceMock).subscribeToUpdates(onUpdate: .any()).then { args in
            let closure: @Sendable ([User]) -> Void = try! args[0]
            closure(userList)
        }
        when(userServiceMock).cachedUserCount.then(return: userList.count)

        viewModel.startSubscribing()

        await Task.yield()

        #expect(viewModel.users == userList)
        #expect(viewModel.userCount == userList.count)

        verify(userServiceMock).subscribeToUpdates(onUpdate: .any()).wasCalled()
    }

    @Test
    func `loadUsers should call service`() async throws {
        let userList = [
            User(id: 0, name: "A", email: "a@b.com"),
            User(id: 1, name: "B", email: "b@c.com"),
            User(id: 2, name: "C", email: "c@d.com")
        ]

        when(userServiceMock).fetchUsers().then(return: userList)

        await viewModel.loadUsers()

        #expect(viewModel.users == userList)

        verify(userServiceMock).fetchUsers().wasCalled()
    }

    @Test
    func `loadUsers should set error message on failure`() async throws {
        when(userServiceMock).fetchUsers().then(throw: TestError.testError)

        await viewModel.loadUsers()

        #expect(viewModel.errorMessage == "testError")

        verify(userServiceMock).fetchUsers().wasCalled()
    }

    @Test
    func `renameUser should call the service`() async throws {
        await populateUsers()

        when(userServiceMock).updateUser(id: 11, name: .any()).then(return: true)

        await viewModel.renameUser(id: 11, newName: "Jim")

        #expect(viewModel.users[1].name == "Jim")
        
        verify(userServiceMock).updateUser(id: 11, name: "Jim").wasCalled()
    }

    @Test
    func `renameUser should set error message on failure`() async throws {
        await populateUsers()

        when(userServiceMock).updateUser(id: 11, name: .any()).then(throw: TestError.testError)

        await viewModel.renameUser(id: 11, newName: "Jim")

        #expect(viewModel.errorMessage == "Failed to rename: testError")

        verify(userServiceMock).updateUser(id: 11, name: "Jim").wasCalled()
    }

    @Test
    func `deleteUser should call the service`() async throws {
        await populateUsers()

        when(userServiceMock).deleteUser(.any()).thenReturn()

        await viewModel.deleteUser(at: IndexSet(integer: 1))

        verify(userServiceMock).deleteUser(11).wasCalled()
    }

    @Test
    func `deleteUser should set error message on failure`() async throws {
        await populateUsers()

        when(userServiceMock).deleteUser(.any()).then(throw: TestError.testError)

        await viewModel.deleteUser(at: IndexSet(integer: 1))

        #expect(viewModel.errorMessage == "Failed to delete: testError")

        verify(userServiceMock).deleteUser(11).wasCalled()
    }

    private func populateUsers() async {
        let userList = [
            User(id: 10, name: "A", email: "a@b.com"),
            User(id: 11, name: "B", email: "b@c.com"),
            User(id: 12, name: "C", email: "c@d.com")
        ]

        when(userServiceMock).fetchUsers().then(return: userList)

        await viewModel.loadUsers()
    }
}
