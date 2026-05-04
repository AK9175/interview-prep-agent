import Foundation
import SwiftData

/// Reads SwiftData locally and builds the structured memory payload
/// sent to /memory/synthesize once per session. Zero network calls.
struct MemoryBuilder {

    // MARK: - Build synthesize request payload

    static func buildSynthesizePayload(
        profile: UserProfile,
        sessions: [InterviewSession],
        episodicMemories: [EpisodicMemory],
        flashcards: [Flashcard]
    ) -> MemorySynthesizeRequest {

        let topicScores = aggregateTopicScores(from: sessions)
        let recentEpisodes = episodicMemories
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0.summary }
            .reversed()
            .map { String($0) }

        let faqActivity = aggregateFAQActivity(from: flashcards)

        return MemorySynthesizeRequest(
            user_profile: [
                "name": profile.name,
                "role": profile.role,
                "level": profile.level,
                "target": profile.target,
                "interview_date": profile.interviewDateString
            ],
            topic_scores: topicScores,
            episodic_memories: recentEpisodes,
            faq_activity: faqActivity
        )
    }

    // MARK: - Build session delta (called after each answer — no network)

    static func buildSessionDelta(from scores: [(topic: String, avg: Double, note: String)]) -> String {
        guard !scores.isEmpty else { return "" }
        return scores.enumerated().map { i, s in
            "Q\(i + 1) (\(s.topic)): avg \(Int(s.avg))/100 — \(s.note)"
        }.joined(separator: "\n")
    }

    // MARK: - Relevant flashcards for FAQ context (topic-filtered, max 5)

    static func relevantFlashcards(for topic: String?, from flashcards: [Flashcard]) -> [FlashcardContext] {
        let filtered: [Flashcard]
        if let topic, !topic.isEmpty {
            filtered = flashcards.filter { $0.topic.lowercased().contains(topic.lowercased()) }
        } else {
            filtered = flashcards
        }
        return filtered
            .sorted { ($0.lastReviewed ?? .distantPast) > ($1.lastReviewed ?? .distantPast) }
            .prefix(5)
            .map { FlashcardContext(question: $0.question, answer: $0.answer, topic: $0.topic) }
    }

    // MARK: - Private helpers

    private static func aggregateTopicScores(from sessions: [InterviewSession]) -> [TopicScorePayload] {
        var topicMap: [String: [Double]] = [:]
        for session in sessions.sorted(by: { $0.createdAt < $1.createdAt }) {
            for score in session.scores {
                topicMap[score.topic, default: []].append(score.average)
            }
        }
        return topicMap.map { TopicScorePayload(topic: $0.key, scores: $0.value) }
            .sorted { $0.scores.last ?? 0 < $1.scores.last ?? 0 } // weakest first
    }

    private static func aggregateFAQActivity(from flashcards: [Flashcard]) -> [FAQActivityPayload] {
        var topicMap: [String: (count: Int, gradeSum: Double)] = [:]
        for card in flashcards where card.lastReviewed != nil {
            topicMap[card.topic, default: (0, 0.0)].count += 1
            topicMap[card.topic, default: (0, 0.0)].gradeSum += card.easeFactor
        }
        return topicMap.map { topic, data in
            FAQActivityPayload(
                topic: topic,
                times_asked: data.count,
                avg_self_grade: data.count > 0 ? data.gradeSum / Double(data.count) : 0
            )
        }
    }
}
