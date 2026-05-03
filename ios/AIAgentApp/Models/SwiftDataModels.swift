import Foundation
import SwiftData

// ── User Profile ─────────────────────────────────────────────────────────────

@Model
final class UserProfile {
    var name: String
    var role: String        // "Software Engineer"
    var level: String       // junior | mid | senior
    var target: String      // "Google"
    var interviewDate: Date

    init(name: String, role: String, level: String, target: String, interviewDate: Date) {
        self.name = name
        self.role = role
        self.level = level
        self.target = target
        self.interviewDate = interviewDate
    }

    var interviewDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: interviewDate)
    }

    var daysUntilInterview: Int {
        Calendar.current.dateComponents([.day], from: .now, to: interviewDate).day ?? 0
    }
}

// ── Interview Session ─────────────────────────────────────────────────────────

@Model
final class InterviewSession {
    var id: UUID
    var role: String
    var level: String
    var domain: String
    var status: String          // active | completed
    var createdAt: Date
    var endedAt: Date?
    var overallScore: Double?
    var episodicSummary: String?
    var weakSpots: [String]

    @Relationship(deleteRule: .cascade)
    var messages: [InterviewMessage] = []

    @Relationship(deleteRule: .cascade)
    var scores: [InterviewScore] = []

    init(role: String, level: String, domain: String) {
        self.id = UUID()
        self.role = role
        self.level = level
        self.domain = domain
        self.status = "active"
        self.createdAt = .now
        self.weakSpots = []
    }
}

@Model
final class InterviewMessage {
    var role: String            // interviewer | candidate
    var content: String
    var timestamp: Date

    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.timestamp = .now
    }
}

@Model
final class InterviewScore {
    var topic: String
    var clarity: Double
    var correctness: Double
    var communication: Double
    var edgeCases: Double
    var feedback: String
    var createdAt: Date

    init(topic: String, clarity: Double, correctness: Double,
         communication: Double, edgeCases: Double, feedback: String) {
        self.topic = topic
        self.clarity = clarity
        self.correctness = correctness
        self.communication = communication
        self.edgeCases = edgeCases
        self.feedback = feedback
        self.createdAt = .now
    }

    var average: Double {
        (clarity + correctness + communication + edgeCases) / 4.0
    }
}

// ── Episodic Memory ──────────────────────────────────────────────────────────

@Model
final class EpisodicMemory {
    var sessionId: UUID
    var summary: String         // written by /interview/summarise
    var createdAt: Date

    init(sessionId: UUID, summary: String) {
        self.sessionId = sessionId
        self.summary = summary
        self.createdAt = .now
    }
}

// ── Flashcards ───────────────────────────────────────────────────────────────

@Model
final class Flashcard {
    var id: UUID
    var question: String
    var answer: String
    var topic: String
    var source: String          // manual | generated | faq
    var createdAt: Date

    // SM-2 spaced repetition state
    var easeFactor: Double      // starts at 2.5
    var interval: Int           // days until next review
    var repetitions: Int
    var nextReview: Date
    var lastReviewed: Date?

    init(question: String, answer: String, topic: String, source: String = "manual") {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.topic = topic
        self.source = source
        self.createdAt = .now
        self.easeFactor = 2.5
        self.interval = 1
        self.repetitions = 0
        self.nextReview = .now
        self.lastReviewed = nil
    }

    var isDueToday: Bool {
        nextReview <= .now
    }
}
