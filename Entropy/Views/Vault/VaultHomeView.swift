import SwiftUI
import SwiftData

struct VaultHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VaultItem.createdAt, order: .reverse) private var items: [VaultItem]
    @State private var isUnlocked = false
    @State private var showingAddDocument = false
    @State private var searchText = ""

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
        Group {
            if isUnlocked {
                unlockedView
            } else {
                lockedView
            }
        }
        .navigationTitle("Vault")
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
                .searchable(text: $searchText, prompt: "Search vault")
                .navigationDestination(for: VaultItem.self) { item in
                    VaultItemDetailView(item: item)
                }
            }
        }
        .toolbar {
            if isUnlocked {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        showingAddDocument = true
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Lock", systemImage: "lock.fill") {
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
