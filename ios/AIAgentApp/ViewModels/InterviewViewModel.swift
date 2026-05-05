import Foundation
import SwiftData
import Observation

@Observable
final class InterviewViewModel {

    // Session state
    var currentQuestion: String = ""
    var sessionActive: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    // Chat messages shown in the UI
    var chatMessages: [ChatMessage] = []

    // Live rubric (shown after each answer)
    var lastScores: RubricScores?
    var lastFeedback: String = ""
    var lastTopic: String = ""

    // Session delta — built locally on device after each answer
    private var sessionDeltaLines: [(topic: String, avg: Double, note: String)] = []
    var sessionDelta: String { MemoryBuilder.buildSessionDelta(from: sessionDeltaLines) }

    // Conversation history sent to backend
    private(set) var history: [MessagePayload] = []

    // Scores collected this session (for summarise call)
    private var collectedScores: [[String: Double]] = []

    // Cached once per session from /memory/synthesize
    var cachedContext: String = ""

    // Reference to active SwiftData session (set by view)
    var activeSession: InterviewSession?

    // MARK: - Start session

    func startSession(
        role: String, level: String, domain: String,
        profile: UserProfile,
        sessions: [InterviewSession],
        episodicMemories: [EpisodicMemory],
        flashcards: [Flashcard],
        modelContext: ModelContext
    ) async {
        isLoading = true
        errorMessage = nil
        sessionDeltaLines = []
        history = []
        collectedScores = []
        chatMessages = []
        lastScores = nil
        lastFeedback = ""
        lastTopic = ""

        do {
            // Step 1 — synthesize memory (once per session, ~300 token payload)
            let payload = MemoryBuilder.buildSynthesizePayload(
                profile: profile,
                sessions: sessions,
                episodicMemories: episodicMemories,
                flashcards: flashcards
            )
            let memRes = try await APIService.shared.synthesizeMemory(payload)
            cachedContext = memRes.context_summary

            // Step 2 — start interview with cached context
            let startRes = try await APIService.shared.startInterview(
                StartInterviewRequest(role: role, level: level, domain: domain, context: cachedContext)
            )

            currentQuestion = startRes.question
            chatMessages.append(ChatMessage(role: "interviewer", content: startRes.question))
            history.append(MessagePayload(role: "interviewer", content: startRes.question))

            // Create SwiftData session
            let session = InterviewSession(role: role, level: level, domain: domain)
            session.messages.append(InterviewMessage(role: "interviewer", content: startRes.question))
            modelContext.insert(session)
            activeSession = session

            sessionActive = true
        } catch let error where error is CancellationError || (error as? URLError)?.code == .cancelled {
            _ = error
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Submit answer

    func submitAnswer(
        _ answer: String,
        role: String, level: String, domain: String,
        modelContext: ModelContext
    ) async {
        guard let session = activeSession else { return }
        isLoading = true
        errorMessage = nil

        // Stage candidate message — only committed to UI on success
        history.append(MessagePayload(role: "candidate", content: answer))

        do {
            let req = SubmitAnswerRequest(
                role: role, level: level, domain: domain,
                context: cachedContext,
                session_delta: sessionDelta,
                history: history,
                answer: answer
            )
            let res = try await APIService.shared.submitAnswer(req)

            // Success — now show candidate message and response
            chatMessages.append(ChatMessage(role: "candidate", content: answer))
            session.messages.append(InterviewMessage(role: "candidate", content: answer))

            // Show rubric to user
            lastScores = res.scores
            lastFeedback = res.feedback
            lastTopic = res.topic
            currentQuestion = res.next_question

            // Save score to SwiftData locally
            let score = InterviewScore(
                topic: res.topic,
                clarity: res.scores.clarity,
                correctness: res.scores.correctness,
                communication: res.scores.communication,
                edgeCases: res.scores.edge_cases,
                feedback: res.feedback
            )
            session.scores.append(score)

            // Update session delta — pure local Swift, zero network
            let avg = res.scores.average
            let note = buildDeltaNote(scores: res.scores, topic: res.topic)
            sessionDeltaLines.append((topic: res.topic, avg: avg, note: note))

            // Add next question to chat and history
            chatMessages.append(ChatMessage(role: "interviewer", content: res.next_question))
            history.append(MessagePayload(role: "interviewer", content: res.next_question))
            session.messages.append(InterviewMessage(role: "interviewer", content: res.next_question))

            collectedScores.append([
                "topic": 0,
                "clarity": res.scores.clarity,
                "correctness": res.scores.correctness,
                "communication": res.scores.communication,
                "edge_cases": res.scores.edge_cases
            ])

        } catch let error where error is CancellationError || (error as? URLError)?.code == .cancelled {
            history.removeLast() // roll back staged message
            _ = error
        } catch {
            history.removeLast() // roll back staged message
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - End session

    func endSession(role: String, level: String, modelContext: ModelContext) async {
        guard let session = activeSession else { return }
        isLoading = true

        // Build scores with topic names from delta lines
        var scoreDicts: [[String: Double]] = []
        for (i, line) in sessionDeltaLines.enumerated() {
            if i < collectedScores.count {
                let d = collectedScores[i]
                _ = line.topic  // topic already in InterviewScore
                scoreDicts.append(d)
            }
        }

        // Inject topic names
        for (i, line) in sessionDeltaLines.enumerated() where i < scoreDicts.count {
            scoreDicts[i]["topic_index"] = Double(i)
            _ = line
        }

        do {
            let req = SummariseRequest(
                role: role, level: level,
                context: cachedContext,
                session_delta: sessionDelta,
                scores: scoreDicts
            )
            let res = try await APIService.shared.summariseSession(req)

            // Save episodic memory to SwiftData
            let episodic = EpisodicMemory(sessionId: session.id, summary: res.summary)
            modelContext.insert(episodic)

            session.status = "completed"
            session.endedAt = .now
            session.overallScore = res.overall_score
            session.episodicSummary = res.summary
            session.weakSpots = res.weak_spots

            sessionActive = false
            cachedContext = ""
            sessionDeltaLines = []
            chatMessages = []

        } catch let error where error is CancellationError || (error as? URLError)?.code == .cancelled {
            _ = error
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Cancel

    func cancelCurrentOperation() {
        isLoading = false
        errorMessage = nil
    }

    // MARK: - Private

    private func buildDeltaNote(scores: RubricScores, topic: String) -> String {
        let avg = scores.average
        var notes: [String] = []
        if scores.edge_cases < 70 { notes.append("edge cases weak") }
        if scores.correctness > 90 { notes.append("strong correctness") }
        if scores.communication < 70 { notes.append("communication needs work") }
        let suffix = notes.isEmpty ? (avg > 80 ? "solid" : "needs reinforcement") : notes.joined(separator: ", ")
        return suffix
    }
}
