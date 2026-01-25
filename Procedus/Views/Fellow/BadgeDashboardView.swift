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
    @State private var showingCOCATSInfo = false

    // MARK: - COCATS Competency Definitions

    struct COCATSCompetency: Identifiable {
        let id: String
        let name: String
        let shortName: String
        let iconName: String
        let color: Color
        let procedureTagIds: [String]
        let levels: [(level: Int, threshold: Int)]
    }

    private static let cocatsCompetencies: [COCATSCompetency] = [
        COCATSCompetency(
            id: "echo",
            name: "Echocardiography",
            shortName: "Echo",
            iconName: "waveform.path.ecg.rectangle",
            color: .blue,
            procedureTagIds: ["ci-echo-tte", "ci-echo-tte-contrast", "ci-echo-tee", "ci-echo-stress"],
            levels: [(1, 150), (2, 300), (3, 750)]
        ),
        COCATSCompetency(
            id: "nuclear",
            name: "Nuclear Cardiology",
            shortName: "Nuclear",
            iconName: "atom",
            color: .green,
            procedureTagIds: ["ci-nuc-spect", "ci-nuc-pet", "ci-nuc-mpi", "ci-stress-nuclear"],
            levels: [(1, 50), (2, 200), (3, 500)]
        ),
        COCATSCompetency(
            id: "ct",
            name: "Cardiac CT",
            shortName: "CT",
            iconName: "viewfinder.circle",
            color: .orange,
            procedureTagIds: ["ci-ct-calcium", "ci-ct-cta", "ci-ct-cardiac"],
            levels: [(1, 25), (2, 150), (3, 300)]
        ),
        COCATSCompetency(
            id: "mri",
            name: "Cardiac MRI",
            shortName: "MRI",
            iconName: "circle.hexagongrid",
            color: .purple,
            procedureTagIds: ["ci-mri-cardiac"],
            levels: [(1, 25), (2, 150), (3, 300)]
        ),
        COCATSCompetency(
            id: "cath",
            name: "Diagnostic Cath",
            shortName: "Cath",
            iconName: "heart.text.square",
            color: .red,
            procedureTagIds: ["ic-dx-lhc", "ic-dx-rhc", "ic-dx-coro", "ic-dx-lv", "ic-dx-ao"],
            levels: [(1, 50), (2, 300)]
        ),
        COCATSCompetency(
            id: "pci",
            name: "PCI",
            shortName: "PCI",
            iconName: "heart.fill",
            color: .pink,
            procedureTagIds: ["ic-pci-stent", "ic-pci-poba", "ic-pci-dcb", "ic-pci-rotablator", "ic-pci-orbital", "ic-pci-laser", "ic-pci-ivl", "ic-pci-thrombectomy"],
            levels: [(3, 250)]
        )
    ]

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

    private var myCases: [CaseEntry] {
        guard let fellowId = currentFellowId else { return [] }
        return allCases.filter { $0.ownerId == fellowId || $0.fellowId == fellowId }
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

    /// Only earned badges for display, sorted newest first
    private var earnedBadgesForDisplay: [Badge] {
        let earnedIds = Set(myEarnedBadges.map { $0.badgeId })
        let allBadges = BadgeCatalog.allBadges()

        // Filter to only earned badges
        var badges = allBadges.filter { earnedIds.contains($0.id) }

        // Apply category filter if selected
        if let category = selectedCategory {
            badges = badges.filter { $0.badgeType == category }
        }

        // Sort by earned date (newest first) using myEarnedBadges order
        return badges.sorted { badge1, badge2 in
            let earned1 = myEarnedBadges.first { $0.badgeId == badge1.id }
            let earned2 = myEarnedBadges.first { $0.badgeId == badge2.id }
            return (earned1?.earnedAt ?? Date.distantPast) > (earned2?.earnedAt ?? Date.distantPast)
        }
    }

    private var progressData: [BadgeProgress] {
        guard let fellowId = currentFellowId else { return [] }
        return BadgeService.shared.getAllProgress(
            fellowId: fellowId,
            cases: allCases,
            earnedBadges: myEarnedBadges,
            enabledPackIds: appState.enabledSpecialtyPackIds
        )
    }

    /// Calculate progress for each COCATS competency
    private func competencyProgress(for competency: COCATSCompetency) -> (count: Int, currentLevel: Int, nextLevel: Int?, nextThreshold: Int?, percentage: Double) {
        // Count procedures matching this competency
        var count = 0
        for caseEntry in myCases {
            for tagId in caseEntry.procedureTagIds {
                if competency.procedureTagIds.contains(tagId) {
                    count += 1
                }
            }
        }

        // Determine current level and next target
        var currentLevel = 0
        var nextLevel: Int? = nil
        var nextThreshold: Int? = nil

        for (level, threshold) in competency.levels {
            if count >= threshold {
                currentLevel = level
            } else {
                nextLevel = level
                nextThreshold = threshold
                break
            }
        }

        // Calculate percentage toward next level
        let percentage: Double
        if let nextThresh = nextThreshold {
            let previousThreshold = competency.levels.first { $0.level == currentLevel }?.threshold ?? 0
            let range = nextThresh - previousThreshold
            let progress = count - previousThreshold
            percentage = range > 0 ? min(1.0, Double(progress) / Double(range)) : 0
        } else {
            // Already at max level
            percentage = 1.0
        }

        return (count, currentLevel, nextLevel, nextThreshold, percentage)
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

                    cocatsProgressSection

                    earnedBadgesSection

                    if !progressData.isEmpty {
                        progressSection
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Achievements")
            .sheet(item: $showingBadgeDetail) { badge in
                // Badges shown from this view are always earned, pass isEarned: true for reliable coloring
                BadgeDetailSheet(
                    badge: badge,
                    earned: myEarnedBadges.first { $0.badgeId == badge.id },
                    isEarned: true
                )
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

    // MARK: - COCATS Progress Section

    private var cocatsProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with info button
            HStack {
                Text("COCATS Competencies")
                    .font(.headline)
                    .foregroundStyle(ProcedusTheme.textPrimary)

                Spacer()

                Button {
                    showingCOCATSInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                ForEach(Self.cocatsCompetencies) { competency in
                    let progress = competencyProgress(for: competency)
                    COCATSProgressCircle(
                        competency: competency,
                        count: progress.count,
                        currentLevel: progress.currentLevel,
                        nextLevel: progress.nextLevel,
                        nextThreshold: progress.nextThreshold,
                        percentage: progress.percentage
                    )
                }
            }
            .padding()
            .background(ProcedusTheme.cardBackground)
            .cornerRadius(16)
        }
        .sheet(isPresented: $showingCOCATSInfo) {
            COCATSInfoSheet(competencies: Self.cocatsCompetencies)
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

    // MARK: - Earned Badges Section

    private var earnedBadgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    BadgeCategoryPill(
                        title: "All",
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

            // Only show earned badges, sorted newest first
            if earnedBadgesForDisplay.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(ProcedusTheme.textTertiary)
                    Text("No badges earned yet")
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                    Text("Complete cases to earn achievements!")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(earnedBadgesForDisplay, id: \.id) { badge in
                        let earned = myEarnedBadges.first { $0.badgeId == badge.id }
                        EarnedBadgeGridItem(badge: badge, earnedAt: earned?.earnedAt)
                            .onTapGesture {
                                showingBadgeDetail = badge
                            }
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

// MARK: - COCATS Progress Circle

struct COCATSProgressCircle: View {
    let competency: BadgeDashboardView.COCATSCompetency
    let count: Int
    let currentLevel: Int
    let nextLevel: Int?
    let nextThreshold: Int?
    let percentage: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                // Progress arc
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(competency.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Icon and count
                VStack(spacing: 0) {
                    Image(systemName: competency.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(competency.color)
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ProcedusTheme.textPrimary)
                }
            }

            Text(competency.shortName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(ProcedusTheme.textPrimary)

            // Level indicator
            HStack(spacing: 2) {
                Text("L\(currentLevel)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(currentLevel > 0 ? competency.color : ProcedusTheme.textTertiary)

                if let nextThresh = nextThreshold {
                    Text("/\(nextThresh)")
                        .font(.system(size: 9))
                        .foregroundStyle(ProcedusTheme.textTertiary)
                }
            }
        }
        .frame(width: 90, height: 110)
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
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.primary
    }
}

// MARK: - Earned Badge Grid Item (only for earned badges, shows date)

struct EarnedBadgeGridItem: View {
    let badge: Badge
    let earnedAt: Date?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(tierColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: badge.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(tierColor)
            }

            Text(badge.title)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(ProcedusTheme.textPrimary)

            if let date = earnedAt {
                Text(date, style: .date)
                    .font(.system(size: 9))
                    .foregroundStyle(ProcedusTheme.textTertiary)
            }
        }
        .frame(width: 100, height: 110)
    }

    private var tierColor: Color {
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.primary
    }
}

// MARK: - Badge Grid Item (legacy, keeping for compatibility)

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
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.primary
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
    /// Explicitly track if badge is earned (for reliable coloring even if lookup fails)
    var isEarned: Bool = true

    private var tierColor: Color {
        BadgeTier(rawValue: badge.tier)?.color ?? ProcedusTheme.primary
    }

    private var tierName: String {
        BadgeTier(rawValue: badge.tier)?.displayName ?? "Badge"
    }

    /// Use isEarned flag OR presence of earned record for display
    private var shouldShowAsEarned: Bool {
        isEarned || earned != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Badge icon with glow - always show in color if earned
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: shouldShowAsEarned ? 20 : 0)

                    Circle()
                        .fill(shouldShowAsEarned ? tierColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: badge.iconName)
                        .font(.system(size: 50))
                        .foregroundStyle(shouldShowAsEarned ? tierColor : Color.gray.opacity(0.4))
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
                } else if isEarned {
                    // Show earned status without date if lookup failed
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("Earned")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)
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

// MARK: - COCATS Info Sheet

struct COCATSInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let competencies: [BadgeDashboardView.COCATSCompetency]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About COCATS Competencies")
                            .font(.headline)
                            .foregroundStyle(ProcedusTheme.textPrimary)

                        Text("COCATS (Core Cardiology Training Symposium) defines competency levels for cardiovascular training. Each level represents increasing proficiency and procedural volume requirements.")
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                    .padding()
                    .background(ProcedusTheme.cardBackground)
                    .cornerRadius(12)

                    // Competencies grouped by category
                    ForEach(competencies) { competency in
                        COCATSCompetencyInfoCard(competency: competency)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("COCATS Levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - COCATS Competency Info Card

struct COCATSCompetencyInfoCard: View {
    let competency: BadgeDashboardView.COCATSCompetency

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: competency.iconName)
                    .font(.title2)
                    .foregroundStyle(competency.color)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(competency.name)
                        .font(.headline)
                        .foregroundStyle(ProcedusTheme.textPrimary)

                    Text(competency.shortName)
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }

                Spacer()
            }

            Divider()

            // Level requirements
            VStack(alignment: .leading, spacing: 8) {
                ForEach(competency.levels, id: \.level) { levelInfo in
                    HStack {
                        // Level badge
                        Text("Level \(levelInfo.level)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(competency.color)
                            .frame(width: 70, alignment: .leading)

                        // Case requirement
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                            Text("\(levelInfo.threshold) cases")
                                .font(.subheadline)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                        }

                        Spacer()

                        // Level description
                        Text(levelDescription(for: levelInfo.level))
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    private func levelDescription(for level: Int) -> String {
        switch level {
        case 1: return "Basic"
        case 2: return "Proficient"
        case 3: return "Advanced"
        default: return ""
        }
    }
}

