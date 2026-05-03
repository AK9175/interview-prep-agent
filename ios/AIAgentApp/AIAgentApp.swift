import SwiftUI
import SwiftData

@main
struct AIAgentApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            UserProfile.self,
            InterviewSession.self,
            InterviewMessage.self,
            InterviewScore.self,
            EpisodicMemory.self,
            Flashcard.self,
        ])
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.isEmpty {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            NavigationStack {
                InterviewView()
            }
            .tabItem { Label("Interview", systemImage: "person.fill.questionmark") }
            .tag(1)

            NavigationStack {
                FAQView()
            }
            .tabItem { Label("FAQ", systemImage: "questionmark.circle.fill") }
            .tag(2)

            NavigationStack {
                FlashcardsView()
            }
            .tabItem { Label("Flashcards", systemImage: "rectangle.stack.fill") }
            .tag(3)

            NavigationStack {
                ProgressDashboardView()
            }
            .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(4)
        }
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var role = "Software Engineer"
    @State private var level = "mid"
    @State private var target = ""
    @State private var interviewDate = Date.now.addingTimeInterval(60 * 60 * 24 * 30)

    var body: some View {
        NavigationStack {
            Form {
                Section("About You") {
                    TextField("Your name", text: $name)
                    TextField("Target role", text: $role)
                    Picker("Level", selection: $level) {
                        Text("Junior").tag("junior")
                        Text("Mid").tag("mid")
                        Text("Senior").tag("senior")
                    }
                }
                Section("Your Goal") {
                    TextField("Target company (e.g. Google)", text: $target)
                    DatePicker("Interview date", selection: $interviewDate, displayedComponents: .date)
                }
                Section {
                    Button("Get Started") { saveProfile() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .disabled(name.isEmpty || target.isEmpty)
                }
            }
            .navigationTitle("Welcome to AI Prep Coach")
        }
    }

    private func saveProfile() {
        let profile = UserProfile(
            name: name, role: role, level: level,
            target: target, interviewDate: interviewDate
        )
        modelContext.insert(profile)
    }
}
