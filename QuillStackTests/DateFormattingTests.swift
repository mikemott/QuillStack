import Testing
import Foundation
@testable import QuillStack

@Suite("Date Formatting")
struct DateFormattingTests {

    // MARK: - Timeline header

    @Test("Today returns 'Today'")
    func today() {
        let now = Date()
        #expect(now.timelineHeader == "Today")
    }

    @Test("Yesterday returns 'Yesterday'")
    func yesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(yesterday.timelineHeader == "Yesterday")
    }

    @Test("Older date in same year omits year")
    func sameYearOmitsYear() {
        var components = Calendar.current.dateComponents([.year], from: Date())
        components.month = 1
        components.day = 15
        let date = Calendar.current.date(from: components)!
        // Only check it doesn't contain the year if we're past January
        let currentMonth = Calendar.current.component(.month, from: Date())
        if currentMonth > 1 {
            let header = date.timelineHeader
            #expect(!header.contains(String(components.year!)))
            #expect(header.contains("January"))
        }
    }

    @Test("Date from previous year includes year")
    func previousYearIncludesYear() {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        let date = Calendar.current.date(from: components)!
        let header = date.timelineHeader
        #expect(header.contains("2025"))
        #expect(header.contains("June"))
    }

    // MARK: - Card timestamp

    @Test("Card timestamp shows time only")
    func cardTimestamp() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 24
        components.hour = 14
        components.minute = 30
        let date = Calendar.current.date(from: components)!
        let result = date.cardTimestamp
        #expect(result.contains("2:30"))
        #expect(result.contains("PM"))
    }

    // MARK: - Detail timestamp

    @Test("Detail timestamp shows month, day, and time")
    func detailTimestamp() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 24
        components.hour = 9
        components.minute = 15
        let date = Calendar.current.date(from: components)!
        let result = date.detailTimestamp
        #expect(result.contains("Mar"))
        #expect(result.contains("24"))
        #expect(result.contains("9:15"))
    }

    // MARK: - Card detail timestamp

    @Test("Card detail timestamp is uppercased")
    func cardDetailUppercased() {
        let date = Date()
        let result = date.cardDetailTimestamp
        #expect(result == result.uppercased())
    }

    @Test("Card detail timestamp includes year and bullet separator")
    func cardDetailFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 12
        components.day = 25
        components.hour = 10
        components.minute = 0
        let date = Calendar.current.date(from: components)!
        let result = date.cardDetailTimestamp
        #expect(result.contains("2026"))
        #expect(result.contains("•"))
    }

    // MARK: - Start of day

    @Test("Start of day has zero time components")
    func startOfDay() {
        let date = Date()
        let start = date.startOfDay
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: start)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }
}
