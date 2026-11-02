//
//  UserListView.swift
//  SmockExample
//
//  Created by Dan Kane on 11/2/26.
//

import SwiftUI

struct UserListView: View {
    @State private var viewModel: UserListViewModel

    // State for the rename alert
    @State private var userToRename: User?
    @State private var newName: String = ""

    init(userService: any UserService = UserServiceImpl()) {
        _viewModel = State(initialValue: UserListViewModel(userService: userService))
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Fetching Users...")
                        Spacer()
                    }
                } else if let errorMessage = viewModel.errorMessage, viewModel.users.isEmpty {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    Section(footer: Text("User Count: \(viewModel.userCount)")) {
                        ForEach(viewModel.users) { user in
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .leading) {
                                Button("Rename") {
                                    userToRename = user
                                    newName = user.name
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { offsets in
                            // onDelete is synchronous, so we wrap the async call in a Task
                            Task {
                                await viewModel.deleteUser(at: offsets)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .refreshable {
                await viewModel.loadUsers()
            }
            // The rename alert
            .alert("Rename User", item: $userToRename) { user in
                TextField("New Name", text: $newName)
                Button("Save") {
                    Task {
                        await viewModel.renameUser(id: user.id, newName: newName)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .task {
                viewModel.startSubscribing()

                // Initial fetch
                if viewModel.users.isEmpty {
                    await viewModel.loadUsers()
                }
            }
        }
    }
}
