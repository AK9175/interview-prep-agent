import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: Int
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [InterviewSession]
    @Query private var flashcards: [Flashcard]

    private var profile: UserProfile? { profiles.first }
    private var dueCards: Int { flashcards.filter { $0.isDueToday }.count }
    private var completedSessions: [InterviewSession] {
        sessions.filter { $0.status == "completed" }.sorted { $0.createdAt > $1.createdAt }
    }
    private var avgScore: Double? {
        let recent = completedSessions.prefix(7).compactMap { $0.overallScore }
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }
    private var topWeakSpots: [String] {
        var freq: [String: Int] = [:]
        for s in completedSessions {
            for spot in s.weakSpots { freq[spot, default: 0] += 1 }
        }
        return freq.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    statsRow
                    todaysPlan
                    quickActions
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Prep Coach")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 6) {
                if let profile {
                    Text("Hey, \(profile.name) 👋")
                        .font(.title2).bold().foregroundStyle(.white)
                    Text("\(max(0, profile.daysUntilInterview)) days until your \(profile.target) interview")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("Welcome back 👋")
                        .font(.title2).bold().foregroundStyle(.white)
                }
            }
            .padding(20)

            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(16)
        }
        .frame(height: 120)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(dueCards)",
                label: "Due Today",
                icon: "rectangle.stack.fill",
                color: dueCards > 0 ? .orange : .green
            )
            StatCard(
                value: avgScore.map { String(format: "%.0f", $0) } ?? "--",
                label: "Avg Score",
                icon: "star.fill",
                color: .blue
            )
            StatCard(
                value: "\(completedSessions.count)",
                label: "Sessions",
                icon: "checkmark.circle.fill",
                color: .purple
            )
        }
    }

    // MARK: - Today's plan

    private var todaysPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Plan")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                if dueCards > 0 {
                    PlanRow(icon: "rectangle.stack.fill",
                            text: "Review \(dueCards) due flashcard\(dueCards > 1 ? "s" : "")",
                            color: .orange)
                }
                ForEach(topWeakSpots, id: \.self) { spot in
                    PlanRow(icon: "target", text: "Practice: \(spot)", color: .red)
                }
                if dueCards == 0 && topWeakSpots.isEmpty {
                    PlanRow(icon: "play.circle.fill",
                            text: "Start a mock interview to build your baseline",
                            color: .blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button { selectedTab = 1 } label: {
                    ActionCard(icon: "person.fill.questionmark", label: "Mock Interview",
                               gradient: [.blue, .cyan])
                }
                Button { selectedTab = 2 } label: {
                    ActionCard(icon: "questionmark.bubble.fill", label: "Ask a Question",
                               gradient: [.green, .teal])
                }
                Button { selectedTab = 3 } label: {
                    ActionCard(icon: "rectangle.stack.fill", label: "Flashcards",
                               gradient: [.orange, .pink])
                }
                Button { selectedTab = 4 } label: {
                    ActionCard(icon: "chart.line.uptrend.xyaxis", label: "Progress",
                               gradient: [.purple, .indigo])
                }
            }
        }
    }
}

// MARK: - Sub-views

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2).bold()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct PlanRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

struct ActionCard: View {
    let icon: String
    let label: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption).bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}
