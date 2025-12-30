//
//  OCRCorrection.swift
//  QuillStack
//
//  Core Data entity for storing learned OCR corrections from user edits.
//

import Foundation
import CoreData

@objc(OCRCorrection)
public class OCRCorrection: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var originalWord: String
    @NSManaged public var correctedWord: String
    @NSManaged public var frequency: Int16
    @NSManaged public var createdAt: Date
    @NSManaged public var lastUsedAt: Date

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        lastUsedAt = Date()
        frequency = 1
    }
}

// MARK: - Convenience Initializer
extension OCRCorrection {
    static func create(
        in context: NSManagedObjectContext,
        originalWord: String,
        correctedWord: String
    ) -> OCRCorrection {
        let correction = OCRCorrection(context: context)
        correction.originalWord = originalWord.lowercased()
        correction.correctedWord = correctedWord
        return correction
    }

    /// Updates the frequency and last used date when this correction is seen again
    func recordUsage() {
        frequency += 1
        lastUsedAt = Date()
    }
}

// MARK: - Fetch Requests
extension OCRCorrection {
    /// Fetches all learned corrections as a dictionary for quick lookup
    static func fetchCorrectionsDictionary(in context: NSManagedObjectContext) -> [String: String] {
        let request = NSFetchRequest<OCRCorrection>(entityName: "OCRCorrection")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OCRCorrection.frequency, ascending: false)]

        do {
            let corrections = try context.fetch(request)
            var dictionary: [String: String] = [:]
            for correction in corrections {
                // Only use corrections that have been seen at least once
                // (frequency starts at 1, so >= 1 means it's been explicitly saved)
                if correction.frequency >= 1 {
                    dictionary[correction.originalWord] = correction.correctedWord
                }
            }
            return dictionary
        } catch {
            print("Failed to fetch OCR corrections: \(error)")
            return [:]
        }
    }

    /// Finds an existing correction for the given original word
    static func find(originalWord: String, in context: NSManagedObjectContext) -> OCRCorrection? {
        let request = NSFetchRequest<OCRCorrection>(entityName: "OCRCorrection")
        request.predicate = NSPredicate(format: "originalWord ==[c] %@", originalWord.lowercased())
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to find OCR correction: \(error)")
            return nil
        }
    }

    /// Fetches corrections sorted by frequency (most used first)
    static func fetchAll(in context: NSManagedObjectContext, limit: Int? = nil) -> [OCRCorrection] {
        let request = NSFetchRequest<OCRCorrection>(entityName: "OCRCorrection")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \OCRCorrection.frequency, ascending: false),
            NSSortDescriptor(keyPath: \OCRCorrection.lastUsedAt, ascending: false)
        ]
        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch OCR corrections: \(error)")
            return []
        }
    }

    /// Gets the total count of learned corrections
    static func count(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<OCRCorrection>(entityName: "OCRCorrection")
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count OCR corrections: \(error)")
            return 0
        }
    }
}
