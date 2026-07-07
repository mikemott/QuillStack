import Foundation

struct TodoExtraction: Codable, Sendable, Identifiable {
    var id = UUID()
    var items: [TodoItem]?

    enum CodingKeys: String, CodingKey {
        case items
    }
}

struct TodoItem: Codable, Sendable {
    var title: String?
    var dueDate: String?
    var priority: String?
    var notes: String?
}
