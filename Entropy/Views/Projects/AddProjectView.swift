import SwiftUI
import SwiftData

struct AddProjectView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var status: ProjectStatus = .active
    @State private var currentStatus = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "folder.fill"

    private let colors = ["blue", "green", "orange", "red", "purple"]
    private let icons = ["folder.fill", "hammer.fill", "desktopcomputer", "iphone",
                          "globe", "cpu.fill", "paintbrush.fill", "wrench.and.screwdriver.fill"]

    var body: some View {
        Form {
            Section("Project Details") {
                TextField("Project Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Current Status") {
                TextField("What are you working on?", text: $currentStatus, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(ProjectStatus.allCases, id: \.self) { s in
                        Label(s.displayName, systemImage: s.icon).tag(s)
                    }
                }
            }

            Section("Appearance") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.caption)
                                    }
                                }
                                .onTapGesture { selectedColor = color }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                }
            }
        }
        .navigationTitle("New Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let project = Project(name: name, description: description, status: status)
                    project.currentStatus = currentStatus
                    project.color = selectedColor
                    project.icon = selectedIcon
                    context.insert(project)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .blue
        }
    }
}
