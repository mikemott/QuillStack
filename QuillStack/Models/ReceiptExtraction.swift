import Foundation

struct ReceiptExtraction: Codable, Sendable {
    var vendor: String?
    var total: String?
    var date: String?
    var currency: String?
}
