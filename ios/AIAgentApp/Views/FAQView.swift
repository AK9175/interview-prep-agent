import SwiftUI
import SwiftData

struct FAQView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flashcards: [Flashcard]

    @State private var vm = FAQViewModel()
    @State private var question = ""
    @State private var topic = ""
    @State private var notes = ""
    @State private var notesTopic = ""
    @State private var selectedTab = 0
    @State private var runningTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    enum Field { case question, topic, notes, notesTopic }

    var cachedContext: String = ""

    var body: some View {
        VStack {
            Picker("", selection: $selectedTab) {
                Text("Ask").tag(0)
                Text("Generate Cards").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedTab == 0 { askView } else { generateView }
        }
        .onTapGesture { focusedField = nil }
        .navigationTitle("FAQ & Study")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Ask view

    private var askView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 10) {
                    TextField("Ask a technical question...", text: $question, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .question)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    TextField("Topic (optional, e.g. algorithms)", text: $topic)
                        .focused($focusedField, equals: .topic)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                    if vm.isLoading {
                        HStack(spacing: 12) {
                            ProgressView().tint(.blue)
                            Text("Getting your answer...")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancel") {
                                runningTask?.cancel()
                                runningTask = nil
                                vm.cancelCurrentOperation()
                            }
                            .font(.subheadline).foregroundStyle(.red)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        Button {
                            focusedField = nil
                            let q = question
                            let t = topic.isEmpty ? nil : topic
                            runningTask = Task {
                                await vm.ask(
                                    question: q, topic: t,
                                    cachedContext: cachedContext,
                                    allFlashcards: flashcards,
                                    modelContext: modelContext
                                )
                            }
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Ask").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(question.isEmpty ? Color(.systemGray3) : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(question.isEmpty)
                    }
                }

                if !vm.answer.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Answer", systemImage: "sparkles")
                                .font(.headline).foregroundStyle(.blue)
                            Spacer()
                            if vm.flashcardSaved {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .font(.caption).fontWeight(.semibold).foregroundStyle(.green)
                            }
                        }
                        Text(vm.answer)
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                        if !vm.relatedTopics.isEmpty {
                            Text("Related Topics").font(.caption).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(vm.relatedTopics, id: \.self) { t in
                                        Text(t)
                                            .font(.caption).fontWeight(.medium)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.12))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Generate view

    private var generateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Topic (e.g. Dynamic Programming)", text: $notesTopic)
                    .focused($focusedField, equals: .notesTopic)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                Text("Paste your notes").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 150)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                if vm.isGenerating {
                    HStack(spacing: 12) {
                        ProgressView().tint(.blue)
                        Text("Generating flashcards...")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") {
                            runningTask?.cancel()
                            runningTask = nil
                            vm.cancelCurrentOperation()
                        }
                        .font(.subheadline).foregroundStyle(.red)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    Button {
                        focusedField = nil
                        runningTask = Task {
                            await vm.generateFlashcards(notes: notes, topic: notesTopic, modelContext: modelContext)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Flashcards").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(notes.isEmpty || notesTopic.isEmpty ? Color(.systemGray3) : Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(notes.isEmpty || notesTopic.isEmpty)
                }

                if !vm.generatedCards.isEmpty {
                    Text("\(vm.generatedCards.count) flashcards created")
                        .font(.headline)
                    ForEach(vm.generatedCards, id: \.question) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.question).font(.subheadline).bold()
                            Text(card.answer).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
    }
}
