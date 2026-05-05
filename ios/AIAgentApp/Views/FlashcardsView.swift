import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCards: [Flashcard]
    @State private var vm = FAQViewModel()
    @State private var showingAnswer = false
    @State private var currentIndex = 0
    @State private var filter: CardFilter = .due

    enum CardFilter: String, CaseIterable {
        case due = "Due Today"
        case all = "All Cards"
    }

    private var cards: [Flashcard] {
        switch filter {
        case .due: return allCards.filter { $0.isDueToday }
        case .all: return allCards
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                ForEach(CardFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            if cards.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    Text(filter == .due ? "All caught up!" : "No flashcards yet")
                        .font(.title3).bold()
                    Text(filter == .due ? "No cards due today. Great work!" : "Generate cards from the FAQ tab.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                let card = cards[min(currentIndex, cards.count - 1)]

                VStack(spacing: 20) {
                    // Progress
                    HStack {
                        Text("\(min(currentIndex + 1, cards.count)) / \(cards.count)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(card.topic)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)

                    // Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                            .shadow(radius: 4)

                        VStack(spacing: 16) {
                            Text(showingAnswer ? "Answer" : "Question")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(showingAnswer ? card.answer : card.question)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .textSelection(.enabled)
                                .padding()
                            if !showingAnswer {
                                Button("Show Answer") { withAnimation { showingAnswer = true } }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .padding(.horizontal)
                    .onTapGesture { withAnimation { showingAnswer.toggle() } }

                    // Grade buttons (shown after revealing answer)
                    if showingAnswer {
                        VStack(spacing: 8) {
                            Text("How well did you know it?")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                GradeButton(label: "Again", color: .red)    { grade(card, 1) }
                                GradeButton(label: "Hard",  color: .orange) { grade(card, 3) }
                                GradeButton(label: "Good",  color: .blue)   { grade(card, 4) }
                                GradeButton(label: "Easy",  color: .green)  { grade(card, 5) }
                            }
                        }
                        .padding(.horizontal)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func grade(_ card: Flashcard, _ g: Int) {
        vm.reviewFlashcard(card, grade: g)
        showingAnswer = false
        if currentIndex < cards.count - 1 {
            currentIndex += 1
        } else {
            currentIndex = 0
        }
    }
}

struct GradeButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
