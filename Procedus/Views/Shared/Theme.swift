// Theme.swift
// Procedus - Unified
// Clinical yet approachable UI theme with all shared components
// NOTE: Enum properties (displayName, color, iconName) are defined in Enums.swift

import SwiftUI

// MARK: - Color Palette

enum ProcedusTheme {
    static let primary = Color(red: 0.20, green: 0.45, blue: 0.70)
    static let primaryDark = Color(red: 0.15, green: 0.35, blue: 0.55)
    static let accent = Color(red: 0.95, green: 0.55, blue: 0.25)
    static let secondary = Color(red: 0.10, green: 0.55, blue: 0.55)
    
    static let background = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
    
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
    
    static let success = Color(red: 0.20, green: 0.65, blue: 0.45)
    static let warning = Color(red: 0.90, green: 0.60, blue: 0.20)
    static let error = Color(red: 0.85, green: 0.30, blue: 0.30)
    static let info = Color(red: 0.30, green: 0.55, blue: 0.85)
    
    static let buttonPrimary = Color(red: 0.20, green: 0.50, blue: 0.80)
    static let buttonSuccess = Color(red: 0.25, green: 0.65, blue: 0.50)
}

// MARK: - Text Styles

extension Font {
    static let clinicalTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let clinicalHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let clinicalBody = Font.system(size: 16, weight: .regular, design: .default)
    static let clinicalCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let clinicalFootnote = Font.system(size: 12, weight: .regular, design: .default)
}

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    let role: UserRole
    let badgeCount: Int
    let action: () -> Void

    /// Role-based bell color
    private var bellColor: Color {
        switch role {
        case .fellow:
            return Color.blue
        case .attending:
            return Color.green
        case .admin:
            return Color.purple
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Solid colored circle background
                Circle()
                    .fill(bellColor)
                    .frame(width: 36, height: 36)

                // Bell icon centered
                Image(systemName: "bell.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)

                // Badge count in center of bell (overlaid)
                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black)  // Always dark for readability
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                        .offset(y: 2)  // Slightly below center for visual balance
                }
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ProcedusTheme.textTertiary)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(ProcedusTheme.primary)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Attestation Status Badge

struct AttestationStatusBadge: View {
    let status: AttestationStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}

// MARK: - Category Bubble

struct CategoryBubble: View {
    let category: ProcedureCategory
    let size: CGFloat
    
    var body: some View {
        Text(category.bubbleLetter ?? String(category.rawValue.prefix(1)))
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.bubbleColor)
            .clipShape(Circle())
    }
}

// MARK: - Outcome Button

struct OutcomeButton: View {
    let outcome: CaseOutcome
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(outcome.rawValue)
                .font(.clinicalCaption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : outcome.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? outcome.color : outcome.color.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Outcome Badge

struct OutcomeBadge: View {
    let outcome: CaseOutcome
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: outcome.iconName)
                .font(.caption2)
            Text(outcome.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(outcome.color.opacity(0.15))
        .foregroundStyle(outcome.color)
        .clipShape(Capsule())
    }
}

// MARK: - Clinical Checkbox Toggle Style

struct ClinicalCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? ProcedusTheme.primary : ProcedusTheme.textTertiary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Passcode Views

struct PasscodeDotsView: View {
    let enteredCount: Int
    let total: Int = 4
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < enteredCount ? ProcedusTheme.primary : Color.gray.opacity(0.3))
                    .frame(width: 14, height: 14)
            }
        }
    }
}

struct PasscodeKeypad: View {
    @Binding var enteredPasscode: String
    let onComplete: () -> Void
    let onBiometricTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { row in
                HStack(spacing: 24) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        PasscodeKey(number: "\(number)") {
                            appendDigit("\(number)")
                        }
                    }
                }
            }
            HStack(spacing: 24) {
                if let onBiometricTap = onBiometricTap {
                    Button(action: onBiometricTap) {
                        Image(systemName: "faceid")
                            .font(.title)
                            .frame(width: 70, height: 70)
                    }
                } else {
                    Color.clear.frame(width: 70, height: 70)
                }
                PasscodeKey(number: "0") { appendDigit("0") }
                Button {
                    if !enteredPasscode.isEmpty {
                        enteredPasscode.removeLast()
                    }
                } label: {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .frame(width: 70, height: 70)
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        guard enteredPasscode.count < 4 else { return }
        enteredPasscode += digit
        if enteredPasscode.count == 4 {
            onComplete()
        }
    }
}

struct PasscodeKey: View {
    let number: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 70, height: 70)
                .background(Color.gray.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// NOTE: All enum extensions (displayName, color, iconName, etc.) are defined in Enums.swift
// DO NOT add extensions here to avoid "Invalid redeclaration" errors

// MARK: - Preview

#Preview("Empty State") {
    EmptyStateView(
        icon: "list.clipboard",
        title: "No Cases",
        message: "You haven't logged any cases yet.",
        actionTitle: "Add Case",
        action: {}
    )
}
