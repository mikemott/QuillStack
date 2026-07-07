import Testing
import Foundation
@testable import QuillStack

@Suite("Tag Model")
struct TagTests {

    // MARK: - Luminance / text color

    @Test("Dark backgrounds use light text", arguments: [
        "#007AFF",  // Event blue
        "#008080",  // Reference teal
    ])
    func darkBackgroundUsesLightText(hex: String) {
        let tag = Tag(name: "Test", colorHex: hex)
        #expect(tag.usesLightText == true)
    }

    @Test("Light backgrounds use dark text", arguments: [
        "#D4FF00",  // Receipt lime
        "#FFFF00",  // Yellow
        "#90EE90",  // Inspiration green
        "#E0E0E0",  // White/gray
        "#FFC107",  // Work amber
    ])
    func lightBackgroundUsesDarkText(hex: String) {
        let tag = Tag(name: "Test", colorHex: hex)
        #expect(tag.usesLightText == false)
    }

    @Test("Handles hex with hash prefix")
    func hexWithHash() {
        let tag = Tag(name: "Test", colorHex: "#FF0000")
        // Red has luminance ~0.299, below 0.5
        #expect(tag.usesLightText == true)
    }

    @Test("Handles hex without hash prefix")
    func hexWithoutHash() {
        let tag = Tag(name: "Test", colorHex: "FFFFFF")
        #expect(tag.usesLightText == false)
    }

    // MARK: - Default tags

    @Test("Default tags have unique names")
    func uniqueNames() {
        let names = Tag.defaults.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("Default tags have valid hex colors")
    func validHexColors() {
        for tag in Tag.defaults {
            let hex = tag.hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            #expect(hex.count == 6, "Tag \(tag.name) has invalid hex: \(tag.hex)")
            #expect(UInt64(hex, radix: 16) != nil, "Tag \(tag.name) hex is not valid: \(tag.hex)")
        }
    }

    @Test("Contact tag exists in defaults")
    func contactExists() {
        #expect(Tag.defaults.contains(where: { $0.name == "Contact" }))
    }

    @Test("Receipt tag exists in defaults")
    func receiptExists() {
        #expect(Tag.defaults.contains(where: { $0.name == "Receipt" }))
    }

    @Test("Event tag exists in defaults")
    func eventExists() {
        #expect(Tag.defaults.contains(where: { $0.name == "Event" }))
    }

    // MARK: - Icon mapping

    @Test("Actionable tags have icons", arguments: ["Receipt", "Event", "Contact"])
    func actionableTagsHaveIcons(name: String) {
        let tag = Tag(name: name, colorHex: "#000000")
        #expect(tag.iconName != "ph-tag-duotone", "Tag \(name) should have a specific icon")
    }

    @Test("Unknown tag gets default icon")
    func unknownTagDefaultIcon() {
        let tag = Tag(name: "SomethingNew", colorHex: "#000000")
        #expect(tag.iconName == "ph-tag-duotone")
    }
}
