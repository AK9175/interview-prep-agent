import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Query private var sessions: [InterviewSession]

    private var completed: [InterviewSession] {
        sessions.filter { $0.status == "completed" }.sorted { $0.createdAt < $1.createdAt }
    }

    private var topicScores: [String: [Double]] {
        var map: [String: [Double]] = [:]
        for s in completed {
            for score in s.scores { map[score.topic, default: []].append(score.average) }
        }
        return map
    }

    private var weakTopics: [(topic: String, avg: Double)] {
        let averaged: [(topic: String, avg: Double)] = topicScores.map { key, values in
            let sum = values.reduce(0.0, +)
            return (topic: key, avg: sum / Double(values.count))
        }
        return Array(averaged.sorted { $0.avg < $1.avg }.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Confidence curve ──────────────────────────────────────
                if completed.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confidence Curve").font(.headline)
                        Chart {
                            ForEach(Array(completed.enumerated()), id: \.offset) { i, session in
                                if let score = session.overallScore {
                                    LineMark(
                                        x: .value("Session", i + 1),
                                        y: .value("Score", score)
                                    )
                                    .foregroundStyle(Color.blue)
                                    PointMark(
                                        x: .value("Session", i + 1),
                                        y: .value("Score", score)
                                    )
                                    .foregroundStyle(Color.blue)
                                }
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 180)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                // ── Topic breakdown ───────────────────────────────────────
                if !weakTopics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic Breakdown").font(.headline)
                        Chart {
                            ForEach(weakTopics, id: \.topic) { item in
                                BarMark(
                                    x: .value("Score", item.avg),
                                    y: .value("Topic", item.topic)
                                )
                                .foregroundStyle(item.avg < 60 ? Color.red : item.avg < 80 ? Color.orange : Color.green)
                            }
                        }
                        .chartXScale(domain: 0...100)
                        .frame(height: CGFloat(weakTopics.count * 44))
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                // ── Session history ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session History").font(.headline)
                    if completed.isEmpty {
                        Text("No sessions yet. Start a mock interview!")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(completed.reversed()) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(session.role) — \(session.domain.capitalized)")
                                        .font(.subheadline).bold()
                                    Text(session.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let score = session.overallScore {
                                    Text(String(format: "%.0f", score))
                                        .font(.title3).bold()
                                        .foregroundStyle(score >= 80 ? .green : score >= 60 ? .orange : .red)
                                }
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
    }
}
