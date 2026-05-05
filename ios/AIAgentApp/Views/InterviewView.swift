import SwiftUI
import SwiftData

struct InterviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [InterviewSession]
    @Query private var episodicMemories: [EpisodicMemory]
    @Query private var flashcards: [Flashcard]

    @State private var vm = InterviewViewModel()
    @State private var userAnswer = ""
    @State private var role = "Software Engineer"
    @State private var level = "mid"
    @State private var domain = "algorithms"
    @State private var showSetup = true
    @State private var showEndAlert = false
    @State private var runningTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            if showSetup && !vm.sessionActive {
                setupView
            } else if vm.isLoading && !vm.sessionActive {
                startingView
            } else if vm.sessionActive {
                interviewView
            }
        }
        .navigationTitle(vm.sessionActive ? "Mock Interview" : "Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.sessionActive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("End", role: .destructive) { showEndAlert = true }
                        .fontWeight(.semibold)
                }
            }
        }
        .alert("End Session?", isPresented: $showEndAlert) {
            Button("End & Save", role: .destructive) {
                inputFocused = false
                Task {
                    await vm.endSession(role: role, level: level, modelContext: modelContext)
                    showSetup = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will generate your session summary and save it to your progress.")
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") {
                vm.errorMessage = nil
                if !vm.sessionActive { showSetup = true }
            }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero
                VStack(spacing: 8) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                        .padding(.top, 16)
                    Text("Mock Interview")
                        .font(.title2).bold()
                    Text("Configure your session below")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Config cards
                VStack(spacing: 12) {
                    SetupField(icon: "briefcase.fill", label: "Role", color: .blue) {
                        TextField("e.g. Software Engineer", text: $role)
                            .font(.subheadline)
                    }
                    SetupField(icon: "chart.bar.fill", label: "Level", color: .purple) {
                        Picker("", selection: $level) {
                            Text("Junior").tag("junior")
                            Text("Mid").tag("mid")
                            Text("Senior").tag("senior")
                        }
                        .pickerStyle(.segmented)
                    }
                    SetupField(icon: "laptopcomputer", label: "Domain", color: .green) {
                        Picker("", selection: $domain) {
                            Text("Algorithms").tag("algorithms")
                            Text("System Design").tag("system-design")
                            Text("Behavioral").tag("behavioral")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Button {
                    showSetup = false
                    runningTask = Task {
                        guard let p = profile else { return }
                        await vm.startSession(
                            role: role, level: level, domain: domain,
                            profile: p,
                            sessions: sessions,
                            episodicMemories: episodicMemories,
                            flashcards: flashcards,
                            modelContext: modelContext
                        )
                        if vm.errorMessage != nil { showSetup = true }
                    }
                } label: {
                    Label("Start Interview", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(vm.isLoading || role.isEmpty)
            }
            .padding()
        }
    }

    // MARK: - Starting (loading between setup and active)

    private var startingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
            }
            VStack(spacing: 6) {
                Text("Preparing your session...")
                    .font(.headline)
                Text("Analysing your progress and building context")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Cancel") {
                runningTask?.cancel()
                runningTask = nil
                vm.cancelCurrentOperation()
                showSetup = true
            }
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }

    // MARK: - Active interview

    private var interviewView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(vm.chatMessages, id: \.id) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }

                        if vm.isLoading {
                            TypingIndicator()
                                .id("typing")
                        }

                        if let scores = vm.lastScores {
                            RubricView(scores: scores, feedback: vm.lastFeedback, topic: vm.lastTopic)
                                .id("rubric")
                        }

                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding()
                }
                .onTapGesture { inputFocused = false }
                .onChange(of: vm.chatMessages.count) {
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: vm.isLoading) {
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            Divider()

            // Input bar
            if vm.isLoading {
                HStack(spacing: 12) {
                    ProgressView().tint(.blue)
                    Text("Evaluating your answer...")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        runningTask?.cancel()
                        runningTask = nil
                        vm.cancelCurrentOperation()
                    }
                    .font(.subheadline).foregroundStyle(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        if userAnswer.isEmpty {
                            Text("Type your answer...")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $userAnswer)
                            .focused($inputFocused)
                            .frame(minHeight: 36, maxHeight: 100)
                            .scrollContentBackground(.hidden)
                    }
                    .padding(10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        let ans = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !ans.isEmpty else { return }
                        userAnswer = ""
                        inputFocused = false
                        runningTask = Task {
                            await vm.submitAnswer(ans, role: role, level: level, domain: domain, modelContext: modelContext)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemGray4) : .blue)
                    }
                    .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
        }
    }
}

// MARK: - Chat message model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

// MARK: - Setup field helper

struct SetupField<Content: View>: View {
    let icon: String
    let label: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(color)
            content
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Chat bubble

struct ChatBubble: View {
    let message: ChatMessage
    private var isInterviewer: Bool { message.role == "interviewer" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isInterviewer {
                Image(systemName: "cpu.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.blue, in: Circle())
            } else {
                Spacer(minLength: 40)
            }

            Text(message.content)
                .font(.subheadline)
                .textSelection(.enabled)
                .padding(12)
                .background(
                    isInterviewer
                        ? Color(.secondarySystemGroupedBackground)
                        : Color.blue
                )
                .foregroundStyle(isInterviewer ? Color.primary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16,
                    style: .continuous))

            if !isInterviewer {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.green, in: Circle())
            } else {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "cpu.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.blue, in: Circle())

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 7, height: 7)
                        .offset(y: phase == i ? -4 : 0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 40)
        }
        .onAppear { phase = 1 }
    }
}

// MARK: - Rubric

struct RubricView: View {
    let scores: RubricScores
    let feedback: String
    let topic: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(topic, systemImage: "checkmark.seal.fill")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.blue)
                Spacer()
                Text(String(format: "%.0f%%", scores.average))
                    .font(.headline).bold()
                    .foregroundStyle(scores.average >= 80 ? .green : scores.average >= 60 ? .orange : .red)
            }

            VStack(spacing: 8) {
                RubricBar(label: "Clarity",       value: scores.clarity)
                RubricBar(label: "Correctness",   value: scores.correctness)
                RubricBar(label: "Communication", value: scores.communication)
                RubricBar(label: "Edge Cases",    value: scores.edge_cases)
            }

            Text(feedback)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RubricBar: View {
    let label: String
    let value: Double
    @State private var animated = false

    private var barColor: Color { value >= 80 ? .green : value >= 60 ? .orange : .red }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(barColor)
                        .frame(width: animated ? geo.size.width * value / 100 : 0, height: 6)
                        .animation(.spring(duration: 0.6).delay(0.1), value: animated)
                }
            }
            .frame(height: 6)
            Text("\(Int(value))").font(.caption2).bold().foregroundStyle(barColor).frame(width: 28)
        }
        .onAppear { animated = true }
    }
}
