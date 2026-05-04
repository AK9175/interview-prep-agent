import Foundation

/// SM-2 spaced repetition algorithm.
/// Grade: 0 = blackout, 1 = wrong, 2 = wrong-easy, 3 = correct-hard, 4 = correct, 5 = perfect
struct SpacedRepetition {

    struct Result {
        let repetitions: Int
        let easeFactor: Double
        let interval: Int
        let nextReview: Date
        let message: String
    }

    static func review(
        repetitions: Int,
        easeFactor: Double,
        interval: Int,
        grade: Int
    ) -> Result {
        let grade = max(0, min(5, grade))

        let newRepetitions: Int
        let newInterval: Int

        if grade >= 3 {
            newRepetitions = repetitions + 1
            switch repetitions {
            case 0:  newInterval = 1
            case 1:  newInterval = 6
            default: newInterval = Int(Double(interval) * easeFactor)
            }
        } else {
            newRepetitions = 0
            newInterval = 1
        }

        let newEF = max(1.3, easeFactor + 0.1 - Double(5 - grade) * (0.08 + Double(5 - grade) * 0.02))

        let nextReview = Calendar.current.date(byAdding: .day, value: newInterval, to: .now) ?? .now

        let messages: [Int: String] = [
            0: "Marked for immediate re-review.",
            1: "Needs more practice — see you tomorrow.",
            2: "Getting there — review again tomorrow.",
            3: "Good effort! Next review in a few days.",
            4: "Solid recall. Next review scheduled.",
            5: "Perfect! Long interval earned."
        ]

        return Result(
            repetitions: newRepetitions,
            easeFactor: newEF,
            interval: newInterval,
            nextReview: nextReview,
            message: messages[grade] ?? "Review recorded."
        )
    }
}
