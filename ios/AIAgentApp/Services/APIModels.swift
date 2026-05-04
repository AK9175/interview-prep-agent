import Foundation

// ── Memory ────────────────────────────────────────────────────────────────────

struct TopicScorePayload: Codable {
    let topic: String
    let scores: [Double]
}

struct FAQActivityPayload: Codable {
    let topic: String
    let times_asked: Int
    let avg_self_grade: Double
}

struct MemorySynthesizeRequest: Codable {
    let user_profile: [String: String]
    let topic_scores: [TopicScorePayload]
    let episodic_memories: [String]
    let faq_activity: [FAQActivityPayload]
}

struct MemorySynthesizeResponse: Codable {
    let context_summary: String
}

// ── Interview ────────────────────────────────────────────────────────────────

struct StartInterviewRequest: Codable {
    let role: String
    let level: String
    let domain: String
    let context: String
}

struct StartInterviewResponse: Codable {
    let question: String
}

struct MessagePayload: Codable {
    let role: String
    let content: String
}

struct SubmitAnswerRequest: Codable {
    let role: String
    let level: String
    let domain: String
    let context: String
    let session_delta: String
    let history: [MessagePayload]
    let answer: String
}

struct RubricScores: Codable {
    let clarity: Double
    let correctness: Double
    let communication: Double
    let edge_cases: Double

    var average: Double {
        (clarity + correctness + communication + edge_cases) / 4.0
    }
}

struct SubmitAnswerResponse: Codable {
    let scores: RubricScores
    let feedback: String
    let topic: String
    let next_question: String
}

struct SummariseRequest: Codable {
    let role: String
    let level: String
    let context: String
    let session_delta: String
    let scores: [[String: Double]]
}

struct SummariseResponse: Codable {
    let overall_score: Double
    let strong_areas: [String]
    let weak_spots: [String]
    let summary: String
    let next_focus: String
}

// ── FAQ ──────────────────────────────────────────────────────────────────────

struct FlashcardContext: Codable {
    let question: String
    let answer: String
    let topic: String
}

struct AskQuestionRequest: Codable {
    let question: String
    let topic: String?
    let context: String
    let relevant_flashcards: [FlashcardContext]
}

struct AskQuestionResponse: Codable {
    let answer: String
    let related_topics: [String]
    let save_as_flashcard: Bool
}

struct GenerateFAQRequest: Codable {
    let notes: String
    let topic: String
}

struct GeneratedFlashcard: Codable {
    let question: String
    let answer: String
}

struct GenerateFAQResponse: Codable {
    let flashcards: [GeneratedFlashcard]
    let topic: String
}
