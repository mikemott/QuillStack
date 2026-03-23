import Foundation

struct ReceiptExtraction: Codable, Sendable {
    var vendor: String?
    var total: String?
    var date: String?
    var currency: String?
    var items: [ReceiptItem]?
}

struct ReceiptItem: Codable, Sendable {
    var name: String?
    var quantity: Int?
    var price: String?
}
