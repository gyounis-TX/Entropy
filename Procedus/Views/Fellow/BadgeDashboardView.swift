// BadgeDashboardView.swift
// Procedus - Unified
// Badge/Achievement dashboard for fellows

import SwiftUI
import SwiftData

struct BadgeDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var earnedBadges: [BadgeEarned]
    @Query private var allCases: [CaseEntry]

    @State private var selectedCategory: BadgeType? = nil
    @State private var showingBadgeDetail: Badge? = nil
    @State private var showingTierLegend = false

    // MARK: - Computed Properties

    private var currentFellowId: UUID? {
        // For institutional mode, use selected fellow or current user
        if !appState.isIndividualMode {
            if let fellowId = appState.selectedFellowId {
                return fellowId
            }
            if let userId = appState.currentUser?.id {
                return userId
            }
        }
        // For individual mode, use persistent UUID from UserDefaults
        return getOrCreateIndividualUserId()
    }

    /// Get or create a persistent user ID for individual mode
    private func getOrCreateIndividualUserId() -> UUID {
        let key = "individualUserUUID"
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: key)
        return newUUID
    }

    private var myEarnedBadges: [BadgeEarned] {
        guard let fellowId = currentFellowId else { return [] }
        return earnedBadges
            .filter { $0.fellowId == fellowId }
            .sorted { $0.earnedAt > $1.earnedAt }
    }

    private var totalPoints: Int {
        myEarnedBadges.reduce(0) { total, earned in
            if let badge = BadgeCatalog.badge(withId: earned.badgeId) {
                return total + badge.pointValue
            }
            return total
        }
    }

    private var filteredBadges: [Badge] {
        let allBadges = BadgeCatalog.allBadges()
        if let category = selectedCategory {
            return allBadges.filter { $0.badgeType == category }
        }
        // Show a curated list when no filter
        return allBadges.filter { badge in
            // Show first procedure badges (any role and primary) and first few milestones
            badge.badgeType == .firstProcedure ||
            badge.badgeType == .firstAsPrimary ||
            badge.badgeType == .totalCases ||
            badge.badgeType == .diversity ||
            (badge.badgeType == .milestone && badge.tier == BadgeTier.bronze.rawValue)
        }
    }

    private var progressData: [BadgeProgress] {
        guard let fellowId = currentFellowId else { return [] }
        return BadgeService.shared.getAllProgress(
            fellowId: fellowId,
            cases: allCases,
            earnedBadges: myEarnedBadges
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard

                    if !myEarnedBadges.isEmpty {
                        recentBadgesSection
                    }

                    if !progressData.isEmpty {
                        progressSection
                    }

                    allBadgesSection
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Achievements")
            .sheet(item: $showingBadgeDetail) { badge in
                BadgeDetailSheet(badge: badge, earned: myEarnedBadges.first { $0.badgeId == badge.id })
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            // Info button in upper right
            HStack {
                Spacer()
                Button {
                    showingTierLegend = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
            }

            // Centered stats
            HStack(spacing: 32) {
                Spacer()

                VStack {
                    Text("\(myEarnedBadges.count)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(ProcedusTheme.primary)
                    Text("Badges Earned")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }

                Divider()
                    .frame(height: 50)

                VStack {
                    Text("\(totalPoints)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(ProcedusTheme.accent)
                    Text("Total Points")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }

                Spacer()
            }

            // Tier distribution - centered
            HStack(spacing: 8) {
                Spacer()
                ForEach(BadgeTier.allCases) { tier in
                    let count = badgesForTier(tier).count
                    TierBadgeCount(tier: tier, count: count)
                }
                Spacer()
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(16)
        .sheet(isPresented: $showingTierLegend) {
            NavigationStack {
                TierLegendView()
                    .padding()
                    .navigationTitle("Badge Tiers")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingTierLegend = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Recent Badges Section

    private var recentBadgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Earned")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(myEarnedBadges.prefix(5)) { earned in
                        if let badge = BadgeCatalog.badge(withId: earned.badgeId) {
                            BadgeCard(badge: badge, earned: earned)
                                .onTapGesture {
                                    showingBadgeDetail = badge
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Milestones")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            VStack(spacing: 12) {
                ForEach(progressData) { progress in
                    MilestoneProgressRow(progress: progress)
                }
            }
            .padding()
            .background(ProcedusTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - All Badges Section

    private var allBadgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    BadgeCategoryPill(
                        title: "Featured",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(BadgeType.allCases) { type in
                        BadgeCategoryPill(
                            title: type.displayName,
                            isSelected: selectedCategory == type
                        ) {
                            selectedCategory = type
                        }
                    }
                }
            }

            // Badge grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                ForEach(filteredBadges, id: \.id) { badge in
                    let isEarned = myEarnedBadges.contains { $0.badgeId == badge.id }
                    BadgeGridItem(badge: badge, isEarned: isEarned)
                        .onTapGesture {
                            showingBadgeDetail = badge
                        }
                }
            }
        }
    }

    // MARK: - Helpers

    private func badgesForTier(_ tier: BadgeTier) -> [BadgeEarned] {
        myEarnedBadges.filter { earned in
            BadgeCatalog.badge(withId: earned.badgeId)?.tier == tier.rawValue
        }
    }
}

// MARK: - Badge Card

struct BadgeCard: View {
    let badge: Badge
    let earned: BadgeEarned

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.iconName)
                .font(.system(size: 32))
                .foregroundStyle(tierColor)

            Text(badge.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(earned.earnedAt, style: .date)
                .font(.caption2)
                .foregroundStyle(ProcedusTheme.textTertiary)
        }
        .frame(width: 100, height: 120)
        .padding()
        .background(tierColor.opacity(0.1))
        .cornerRadius(12)
    }

    private var tierColor: Color {
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.textSecondary
    }
}

// MARK: - Badge Grid Item

struct BadgeGridItem: View {
    let badge: Badge
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isEarned ? tierColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: badge.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(isEarned ? tierColor : Color.gray.opacity(0.4))
            }

            Text(badge.title)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(isEarned ? ProcedusTheme.textPrimary : ProcedusTheme.textTertiary)
        }
        .frame(width: 100, height: 100)
        .opacity(isEarned ? 1.0 : 0.5)
    }

    private var tierColor: Color {
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.textSecondary
    }
}

// MARK: - Tier Badge Count

struct TierBadgeCount: View {
    let tier: BadgeTier
    let count: Int

    @State private var showingInfo = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.iconName)
                .font(.caption)
                .foregroundStyle(tier.color)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tier.color.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            showingInfo = true
        }
        .popover(isPresented: $showingInfo) {
            TierInfoPopover(tier: tier)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Tier Info Popover

struct TierInfoPopover: View {
    let tier: BadgeTier

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: tier.iconName)
                    .font(.title2)
                    .foregroundStyle(tier.color)
                Text(tier.displayName)
                    .font(.headline)
                    .foregroundStyle(tier.color)
            }

            Text(tier.tierDescription)
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)

            Divider()

            Text(tier.pointRange)
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textTertiary)
        }
        .padding()
        .frame(minWidth: 200)
    }
}

// MARK: - Tier Legend View

struct TierLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badge Tiers")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            VStack(spacing: 8) {
                ForEach(BadgeTier.allCases) { tier in
                    HStack(spacing: 12) {
                        Image(systemName: tier.iconName)
                            .font(.body)
                            .foregroundStyle(tier.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(tier.color)
                            Text(tier.tierDescription)
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                        }

                        Spacer()

                        Text(tier.pointRange)
                            .font(.caption2)
                            .foregroundStyle(ProcedusTheme.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Milestone Progress Row

struct MilestoneProgressRow: View {
    let progress: BadgeProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: progress.iconName)
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.primary)
                Text(progress.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(progress.current) / \(progress.next)")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ProcedusTheme.primary)
                        .frame(width: geometry.size.width * progress.percentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Badge Category Pill

struct BadgeCategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : ProcedusTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? ProcedusTheme.primary : Color.gray.opacity(0.15))
                .cornerRadius(16)
        }
    }
}

// MARK: - Badge Detail Sheet

struct BadgeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let badge: Badge
    let earned: BadgeEarned?

    private var tierColor: Color {
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.textSecondary
    }

    private var tierName: String {
        BadgeTier(rawValue: badge.tier)?.displayName ?? "Badge"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Badge icon with glow
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: earned != nil ? 20 : 0)

                    Circle()
                        .fill(earned != nil ? tierColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: badge.iconName)
                        .font(.system(size: 50))
                        .foregroundStyle(earned != nil ? tierColor : Color.gray.opacity(0.4))
                }

                VStack(spacing: 8) {
                    Text(badge.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(ProcedusTheme.textPrimary)

                    Text(badge.descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Label(tierName, systemImage: BadgeTier(rawValue: badge.tier)?.iconName ?? "circle")
                            .font(.caption)
                            .foregroundStyle(tierColor)

                        Label("+\(badge.pointValue) pts", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.accent)
                    }
                    .padding(.top, 8)
                }

                if let earned = earned {
                    VStack(spacing: 4) {
                        Text("Earned")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textTertiary)
                        Text(earned.earnedAt, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Text("Not yet earned")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textTertiary)
                        .italic()
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

