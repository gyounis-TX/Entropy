// BadgeCelebrationView.swift
// Procedus - Unified
// Celebration overlay when a badge is earned

import SwiftUI

struct BadgeCelebrationView: View {
    let badge: Badge
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var iconScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0

    private var tierColor: Color {
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.primary
    }

    private var tierName: String {
        BadgeTier(rawValue: badge.tier)?.displayName ?? "Badge"
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Badge celebration card
            VStack(spacing: 24) {
                // Icon with glow effect
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(tierColor.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .blur(radius: 30)
                        .opacity(glowOpacity)

                    // Inner glow
                    Circle()
                        .fill(tierColor.opacity(0.2))
                        .frame(width: 100, height: 100)

                    // Badge icon
                    Image(systemName: badge.iconName)
                        .font(.system(size: 50))
                        .foregroundStyle(tierColor)
                        .scaleEffect(iconScale)
                }

                VStack(spacing: 12) {
                    Text("Achievement Unlocked!")
                        .font(.headline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)

                    Text(badge.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(ProcedusTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)

                    Text(badge.descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)

                    // Points and tier info
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: BadgeTier(rawValue: badge.tier)?.iconName ?? "circle")
                                .font(.caption)
                            Text(tierName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(tierColor)

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text("+\(badge.pointValue) points")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(ProcedusTheme.accent)
                    }
                    .padding(.top, 8)
                    .opacity(showContent ? 1 : 0)
                }

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)
            }
            .padding(32)
            .background(ProcedusTheme.cardBackground)
            .cornerRadius(24)
            .shadow(color: tierColor.opacity(0.3), radius: 30)
            .padding(32)
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                iconScale = 1.0
            }

            withAnimation(.easeOut(duration: 0.8)) {
                glowOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Multiple Badges Celebration

struct MultipleBadgesCelebrationView: View {
    let badges: [Badge]
    @State private var currentIndex = 0
    let onComplete: () -> Void

    var body: some View {
        if currentIndex < badges.count {
            BadgeCelebrationView(badge: badges[currentIndex]) {
                if currentIndex < badges.count - 1 {
                    currentIndex += 1
                } else {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Badge Notification Banner

struct BadgeEarnedBanner: View {
    let badge: Badge
    let onTap: () -> Void

    private var tierColor: Color {
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.primary
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: badge.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(tierColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievement Unlocked!")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)

                    Text(badge.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ProcedusTheme.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
            }
            .padding()
            .background(ProcedusTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    BadgeCelebrationView(
        badge: Badge(
            id: "preview-badge",
            title: "First PCI",
            description: "Completed your first coronary intervention as primary operator",
            iconName: "heart.fill",
            badgeType: .firstAsPrimary,
            criteria: .firstAsPrimary(procedureTagId: "test"),
            tier: .gold,
            pointValue: 100
        )
    ) {
        print("Dismissed")
    }
}
