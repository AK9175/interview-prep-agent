import Foundation
import SwiftData
import Observation

@Observable
final class FAQViewModel {

    var answer: String = ""
    var relatedTopics: [String] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var flashcardSaved: Bool = false

    // Flashcard generation
    var generatedCards: [GeneratedFlashcard] = []
    var isGenerating: Bool = false

    // MARK: - Ask a question

    func ask(
        question: String,
        topic: String?,
        cachedContext: String,
        allFlashcards: [Flashcard],
        modelContext: ModelContext
    ) async {
        isLoading = true
        errorMessage = nil
        flashcardSaved = false

        // iOS selects relevant flashcards locally — no raw dump
        let relevant = MemoryBuilder.relevantFlashcards(for: topic, from: allFlashcards)

        let req = AskQuestionRequest(
            question: question,
            topic: topic,
            context: cachedContext,
            relevant_flashcards: relevant
        )

        do {
            let res = try await APIService.shared.askQuestion(req)
            answer = res.answer
            relatedTopics = res.related_topics

            if res.save_as_flashcard {
                let card = Flashcard(
                    question: question,
                    answer: res.answer,
                    topic: topic ?? "general",
                    source: "faq"
                )
                modelContext.insert(card)
                flashcardSaved = true
            }
        } catch let error where error is CancellationError || (error as? URLError)?.code == .cancelled {
            _ = error
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Generate flashcards from notes

    func generateFlashcards(notes: String, topic: String, modelContext: ModelContext) async {
        isGenerating = true
        errorMessage = nil

        do {
            let res = try await APIService.shared.generateFlashcards(
                GenerateFAQRequest(notes: notes, topic: topic)
            )
            generatedCards = res.flashcards

            // Save all to SwiftData on device
            for card in res.flashcards {
                let fc = Flashcard(
                    question: card.question,
                    answer: card.answer,
                    topic: topic,
                    source: "generated"
                )
                modelContext.insert(fc)
            }
        } catch let error where error is CancellationError || (error as? URLError)?.code == .cancelled {
            _ = error
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Cancel

    func cancelCurrentOperation() {
        isLoading = false
        isGenerating = false
        errorMessage = nil
    }

    // MARK: - Review a flashcard (SM-2, fully local — no network)

    func reviewFlashcard(_ flashcard: Flashcard, grade: Int) {
        let result = SpacedRepetition.review(
            repetitions: flashcard.repetitions,
            easeFactor: flashcard.easeFactor,
            interval: flashcard.interval,
            grade: grade
        )
        flashcard.repetitions = result.repetitions
        flashcard.easeFactor = result.easeFactor
        flashcard.interval = result.interval
        flashcard.nextReview = result.nextReview
        flashcard.lastReviewed = .now
    }
}
