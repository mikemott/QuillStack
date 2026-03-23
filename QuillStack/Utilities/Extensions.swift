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
    var timelineHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(self, equalTo: .now, toGranularity: .year)
            ? "MMMM d"
            : "MMMM d, yyyy"
        return formatter.string(from: self)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var cardTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }

    var detailTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: self)
    }

    var cardDetailTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        return formatter.string(from: self).uppercased()
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

    func toBase64JPEG(quality: CGFloat = 0.8) -> String? {
        guard let data = jpegData(compressionQuality: quality) else { return nil }
        return data.base64EncodedString()
    }
}
