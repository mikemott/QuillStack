import SwiftUI
import UIKit

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else {
            self.init(.gray)
            return
        }
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Date Formatting

extension Date {
    private static let sameYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f
    }()

    private static let fullYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    private static let cardTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let detailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    private static let cardDetailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy • h:mm a"
        return f
    }()

    var timelineHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        if calendar.isDate(self, equalTo: .now, toGranularity: .year) {
            return Date.sameYearFormatter.string(from: self)
        }
        return Date.fullYearFormatter.string(from: self)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var cardTimestamp: String {
        Date.cardTimestampFormatter.string(from: self)
    }

    var detailTimestamp: String {
        Date.detailFormatter.string(from: self)
    }

    var cardDetailTimestamp: String {
        Date.cardDetailFormatter.string(from: self).uppercased()
    }
}

// MARK: - Data to UIImage

extension Data {
    var uiImage: UIImage? { UIImage(data: self) }
}

// MARK: - UIImage Helpers

extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func thumbnail(maxDimension: CGFloat = 300) -> Data? {
        let normalized = normalizedOrientation()
        let scale = min(maxDimension / normalized.size.width, maxDimension / normalized.size.height, 1.0)
        let newSize = CGSize(width: normalized.size.width * scale, height: normalized.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let image = renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return image.jpegData(compressionQuality: 0.7)
    }

}
