import SwiftUI
import SwiftData

struct VaultHomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \VaultItem.createdAt, order: .reverse) private var items: [VaultItem]
    @State private var isUnlocked = false
    @State private var showingAddDocument = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    private var groupedItems: [(VaultItemType, [VaultItem])] {
        let filtered = searchText.isEmpty ? items : items.filter {
            $0.label.localizedCaseInsensitiveContains(searchText)
        }
        let grouped = Dictionary(grouping: filtered, by: \.type)
        return VaultItemType.allCases.compactMap { type in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            return (type, items)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isUnlocked {
                    unlockedView
                } else {
                    lockedView
                }
            }
            .navigationTitle("Vault")
            .onAppear { handleDeepLink() }
            .onChange(of: appState.deepLinkAction) { handleDeepLink() }
        }
    }

    private func handleDeepLink() {
        guard case .viewVaultItem(let id) = appState.deepLinkAction else { return }
        appState.consumeDeepLink()
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<VaultItem>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let item = try? context.fetch(descriptor).first else { return }
        // Auto-unlock and navigate
        Task {
            isUnlocked = await VaultSecurityService.shared.authenticate()
            if isUnlocked {
                navigationPath.append(item)
            }
        }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Personal Vault")
                .font(.title2)
                .fontWeight(.bold)

            Text("Your documents are protected with \(VaultSecurityService.shared.biometricName).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await unlock() }
            } label: {
                Label("Unlock with \(VaultSecurityService.shared.biometricName)",
                      systemImage: biometricIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private var unlockedView: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No Documents", systemImage: "doc.badge.plus")
                } description: {
                    Text("Add passports, licenses, insurance cards, and other important documents.")
                } actions: {
                    Button("Add Document") { showingAddDocument = true }
                        .buttonStyle(.borderedProminent)
                }
            } else if groupedItems.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No documents match your search.")
                }
            } else {
                List {
                    ForEach(groupedItems, id: \.0) { type, typeItems in
                        Section(type.displayName) {
                            ForEach(typeItems) { item in
                                NavigationLink(value: item) {
                                    VaultItemRow(item: item)
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    context.delete(typeItems[index])
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: VaultItem.self) { item in
                    VaultItemDetailView(item: item)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search vault")
        .toolbar {
            if isUnlocked {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        showingAddDocument = true
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Lock", systemImage: "lock.fill") {
                        navigationPath = NavigationPath()
                        showingAddDocument = false
                        isUnlocked = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddDocument) {
            NavigationStack {
                AddDocumentView()
            }
        }
    }

    private func unlock() async {
        isUnlocked = await VaultSecurityService.shared.authenticate()
    }

    private var biometricIcon: String {
        switch VaultSecurityService.shared.availableBiometric {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.open.fill"
        }
    }
}

struct VaultItemRow: View {
    let item: VaultItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.icon)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.headline)
                Text(item.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isExpired {
                Label("Expired", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if item.isExpiringSoon {
                Label("Expiring", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}
