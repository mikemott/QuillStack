//
//  PDFExporter.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import UIKit
import PDFKit

/// Exports notes as PDF documents with professional formatting
class PDFExporter: ExportDestination {
    let type: ExportDestinationType = .pdf

    // PDF layout constants
    private let pageWidth: CGFloat = 612  // 8.5 inches at 72 dpi
    private let pageHeight: CGFloat = 792 // 11 inches at 72 dpi
    private let margin: CGFloat = 72      // 1 inch margins

    private var contentWidth: CGFloat { pageWidth - (margin * 2) }
    private var contentHeight: CGFloat { pageHeight - (margin * 2) }

    func isConfigured() -> Bool {
        // PDF export is always available - no configuration needed
        true
    }

    func getMissingConfiguration() -> [String] {
        // No configuration required
        []
    }

    func export(request: ExportRequest) async throws -> ExportResult {
        let pdfData = generatePDF(from: request)

        // Save to temporary file
        let fileName = sanitizeFileName(request.content.title) + ".pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: tempURL)

            // Present share sheet on main thread
            await MainActor.run {
                presentShareSheet(for: tempURL)
            }

            return .success(
                destination: .pdf,
                path: tempURL.path,
                message: "PDF ready to share",
                openURL: nil
            )
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }
    }

    // MARK: - PDF Generation

    private func generatePDF(from request: ExportRequest) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            var currentY: CGFloat = margin

            // Start first page
            context.beginPage()

            // Draw header
            currentY = drawHeader(
                context: context,
                noteType: request.note.noteType,
                y: currentY
            )

            // Draw title
            currentY = drawTitle(
                context: context,
                title: request.content.title,
                y: currentY
            )

            // Draw metadata
            currentY = drawMetadata(
                context: context,
                metadata: request.content.metadata,
                y: currentY
            )

            // Draw original image if included
            if request.options.includeOriginalImage,
               let imageData = request.note.originalImageData,
               let image = UIImage(data: imageData) {
                currentY = drawImage(
                    context: context,
                    image: image,
                    y: currentY
                )
            }

            // Draw section header for transcribed text
            currentY = drawSectionHeader(
                context: context,
                text: "Transcribed Text",
                y: currentY
            )

            // Draw content based on note type
            switch request.note.noteType.lowercased() {
            case "todo":
                currentY = drawTodoContent(
                    context: context,
                    note: request.note,
                    content: request.content,
                    y: currentY
                )
            case "meeting":
                currentY = drawMeetingContent(
                    context: context,
                    note: request.note,
                    content: request.content,
                    y: currentY
                )
            case "email":
                currentY = drawEmailContent(
                    context: context,
                    content: request.content,
                    y: currentY
                )
            default:
                currentY = drawGeneralContent(
                    context: context,
                    content: request.content.plainBody,
                    y: currentY
                )
            }

            // Draw footer on current page
            drawFooter(context: context, pageNumber: 1, totalPages: 1)
        }
    }

    // MARK: - Drawing Methods

    private func drawHeader(context: UIGraphicsPDFRendererContext, noteType: String, y: CGFloat) -> CGFloat {
        var currentY = y

        // Type badge
        let badgeFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let badgeText = noteType.uppercased()
        let badgeColor = badgeColor(for: noteType)

        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: UIColor.white
        ]

        let badgeSize = badgeText.size(withAttributes: badgeAttributes)
        let badgePadding: CGFloat = 8
        let badgeRect = CGRect(
            x: margin,
            y: currentY,
            width: badgeSize.width + badgePadding * 2,
            height: badgeSize.height + badgePadding
        )

        // Draw badge background
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
        badgeColor.setFill()
        badgePath.fill()

        // Draw badge text
        let badgeTextRect = CGRect(
            x: badgeRect.minX + badgePadding,
            y: badgeRect.minY + badgePadding / 2,
            width: badgeSize.width,
            height: badgeSize.height
        )
        badgeText.draw(in: badgeTextRect, withAttributes: badgeAttributes)

        // App name on right
        let appNameFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let appNameAttributes: [NSAttributedString.Key: Any] = [
            .font: appNameFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        let appName = "QuillStack"
        let appNameSize = appName.size(withAttributes: appNameAttributes)
        let appNameRect = CGRect(
            x: pageWidth - margin - appNameSize.width,
            y: currentY + (badgeRect.height - appNameSize.height) / 2,
            width: appNameSize.width,
            height: appNameSize.height
        )
        appName.draw(in: appNameRect, withAttributes: appNameAttributes)

        currentY = badgeRect.maxY + 20

        return currentY
    }

    private func drawTitle(context: UIGraphicsPDFRendererContext, title: String, y: CGFloat) -> CGFloat {
        let titleFont = UIFont(name: "Georgia-Bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]

        let titleRect = CGRect(x: margin, y: y, width: contentWidth, height: 60)
        let boundingRect = title.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: titleAttributes,
            context: nil
        )

        title.draw(in: titleRect, withAttributes: titleAttributes)

        return y + boundingRect.height + 12
    }

    private func drawMetadata(context: UIGraphicsPDFRendererContext, metadata: ExportMetadata, y: CGFloat) -> CGFloat {
        let metaFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let metaColor = UIColor.secondaryLabel

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var metaText = "Created: \(dateFormatter.string(from: metadata.createdAt))"

        if let confidence = metadata.ocrConfidence {
            metaText += "  •  OCR Confidence: \(Int(confidence * 100))%"
        }

        if !metadata.tags.isEmpty {
            metaText += "\nTags: \(metadata.tags.joined(separator: ", "))"
        }

        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: metaColor
        ]

        let metaRect = CGRect(x: margin, y: y, width: contentWidth, height: 40)
        metaText.draw(in: metaRect, withAttributes: metaAttributes)

        // Draw separator line
        let lineY = y + 35
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: lineY))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: lineY))
        UIColor.separator.setStroke()
        linePath.lineWidth = 0.5
        linePath.stroke()

        return lineY + 20
    }

    private func drawImage(context: UIGraphicsPDFRendererContext, image: UIImage, y: CGFloat) -> CGFloat {
        // Scale image to fit content width while maintaining aspect ratio
        let maxImageHeight: CGFloat = 250
        let imageAspect = image.size.width / image.size.height
        var imageWidth = contentWidth
        var imageHeight = imageWidth / imageAspect

        if imageHeight > maxImageHeight {
            imageHeight = maxImageHeight
            imageWidth = imageHeight * imageAspect
        }

        // Center the image
        let imageX = margin + (contentWidth - imageWidth) / 2
        let imageRect = CGRect(x: imageX, y: y, width: imageWidth, height: imageHeight)

        // Draw border
        let borderRect = imageRect.insetBy(dx: -2, dy: -2)
        UIColor.separator.setStroke()
        let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 4)
        borderPath.lineWidth = 1
        borderPath.stroke()

        // Draw image
        image.draw(in: imageRect)

        // Caption
        let captionFont = UIFont.italicSystemFont(ofSize: 10)
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        let caption = "Original handwritten note"
        let captionSize = caption.size(withAttributes: captionAttributes)
        let captionRect = CGRect(
            x: margin + (contentWidth - captionSize.width) / 2,
            y: imageRect.maxY + 4,
            width: captionSize.width,
            height: captionSize.height
        )
        caption.draw(in: captionRect, withAttributes: captionAttributes)

        return captionRect.maxY + 20
    }

    private func drawSectionHeader(context: UIGraphicsPDFRendererContext, text: String, y: CGFloat) -> CGFloat {
        let headerFont = UIFont(name: "Georgia-Bold", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .bold)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.label
        ]

        let headerRect = CGRect(x: margin, y: y, width: contentWidth, height: 20)
        text.draw(in: headerRect, withAttributes: headerAttributes)

        return y + 24
    }

    private func drawGeneralContent(context: UIGraphicsPDFRendererContext, content: String, y: CGFloat) -> CGFloat {
        let bodyFont = UIFont(name: "Georgia", size: 12) ?? UIFont.systemFont(ofSize: 12)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = CGRect(x: margin, y: y, width: contentWidth, height: contentHeight - (y - margin))
        content.draw(in: textRect, withAttributes: bodyAttributes)

        let boundingRect = content.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: bodyAttributes,
            context: nil
        )

        return y + boundingRect.height + 12
    }

    private func drawTodoContent(context: UIGraphicsPDFRendererContext, note: Note, content: FormattedExportContent, y: CGFloat) -> CGFloat {
        var currentY = y

        let todoItems = (note.todoItems?.allObjects as? [TodoItem]) ?? []
        let sortedItems = todoItems.sorted { $0.sortOrder < $1.sortOrder }

        if sortedItems.isEmpty {
            return drawGeneralContent(context: context, content: content.plainBody, y: y)
        }

        let bodyFont = UIFont(name: "Georgia", size: 12) ?? UIFont.systemFont(ofSize: 12)
        let checkboxSize: CGFloat = 14
        let itemSpacing: CGFloat = 8

        for item in sortedItems {
            // Draw checkbox
            let checkboxRect = CGRect(x: margin, y: currentY, width: checkboxSize, height: checkboxSize)
            let checkboxPath = UIBezierPath(roundedRect: checkboxRect, cornerRadius: 2)
            UIColor.separator.setStroke()
            checkboxPath.lineWidth = 1
            checkboxPath.stroke()

            if item.isCompleted {
                // Draw checkmark
                let checkPath = UIBezierPath()
                checkPath.move(to: CGPoint(x: checkboxRect.minX + 3, y: checkboxRect.midY))
                checkPath.addLine(to: CGPoint(x: checkboxRect.midX - 1, y: checkboxRect.maxY - 3))
                checkPath.addLine(to: CGPoint(x: checkboxRect.maxX - 2, y: checkboxRect.minY + 3))
                UIColor.systemGreen.setStroke()
                checkPath.lineWidth = 2
                checkPath.stroke()
            }

            // Draw text
            var textAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: item.isCompleted ? UIColor.secondaryLabel : UIColor.label
            ]

            if item.isCompleted {
                textAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            let textX = margin + checkboxSize + 8
            let textRect = CGRect(x: textX, y: currentY, width: contentWidth - checkboxSize - 8, height: 20)
            item.text.draw(in: textRect, withAttributes: textAttributes)

            currentY += checkboxSize + itemSpacing
        }

        return currentY + 12
    }

    private func drawMeetingContent(context: UIGraphicsPDFRendererContext, note: Note, content: FormattedExportContent, y: CGFloat) -> CGFloat {
        var currentY = y

        guard let meeting = note.meeting else {
            return drawGeneralContent(context: context, content: content.plainBody, y: y)
        }

        let labelFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let bodyFont = UIFont(name: "Georgia", size: 12) ?? UIFont.systemFont(ofSize: 12)

        // Attendees
        if let attendees = meeting.attendees, !attendees.isEmpty {
            currentY = drawLabeledSection(
                context: context,
                label: "Attendees",
                content: attendees,
                labelFont: labelFont,
                bodyFont: bodyFont,
                y: currentY
            )
        }

        // Agenda
        if let agenda = meeting.agenda, !agenda.isEmpty {
            currentY = drawLabeledSection(
                context: context,
                label: "Agenda",
                content: agenda,
                labelFont: labelFont,
                bodyFont: bodyFont,
                y: currentY
            )
        }

        // Action Items
        if let actionItems = meeting.actionItems, !actionItems.isEmpty {
            currentY = drawLabeledSection(
                context: context,
                label: "Action Items",
                content: actionItems,
                labelFont: labelFont,
                bodyFont: bodyFont,
                y: currentY
            )
        }

        return currentY
    }

    private func drawEmailContent(context: UIGraphicsPDFRendererContext, content: FormattedExportContent, y: CGFloat) -> CGFloat {
        // Email content is already formatted in plainBody
        return drawGeneralContent(context: context, content: content.plainBody, y: y)
    }

    private func drawLabeledSection(context: UIGraphicsPDFRendererContext, label: String, content: String, labelFont: UIFont, bodyFont: UIFont, y: CGFloat) -> CGFloat {
        var currentY = y

        // Label
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        let labelRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 16)
        label.draw(in: labelRect, withAttributes: labelAttributes)
        currentY += 18

        // Content
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]
        let boundingRect = content.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        let contentRect = CGRect(x: margin, y: currentY, width: contentWidth, height: boundingRect.height)
        content.draw(in: contentRect, withAttributes: contentAttributes)
        currentY += boundingRect.height + 16

        return currentY
    }

    private func drawFooter(context: UIGraphicsPDFRendererContext, pageNumber: Int, totalPages: Int) {
        let footerFont = UIFont.systemFont(ofSize: 9, weight: .regular)
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.tertiaryLabel
        ]

        // Page number
        let pageText = "Page \(pageNumber) of \(totalPages)"
        let pageSize = pageText.size(withAttributes: footerAttributes)
        let pageRect = CGRect(
            x: margin,
            y: pageHeight - margin + 20,
            width: pageSize.width,
            height: pageSize.height
        )
        pageText.draw(in: pageRect, withAttributes: footerAttributes)

        // Generated by
        let generatedText = "Generated by QuillStack"
        let generatedSize = generatedText.size(withAttributes: footerAttributes)
        let generatedRect = CGRect(
            x: pageWidth - margin - generatedSize.width,
            y: pageHeight - margin + 20,
            width: generatedSize.width,
            height: generatedSize.height
        )
        generatedText.draw(in: generatedRect, withAttributes: footerAttributes)
    }

    // MARK: - Helpers

    private func badgeColor(for noteType: String) -> UIColor {
        switch noteType.lowercased() {
        case "todo": return UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0)
        case "meeting": return UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0)
        case "email": return UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        default: return UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0)
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        let trimmed = String(sanitized.prefix(50))
        return trimmed.isEmpty ? "QuillStack_Note" : trimmed
    }

    @MainActor
    private func presentShareSheet(for url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topController.present(activityVC, animated: true)
    }
}
