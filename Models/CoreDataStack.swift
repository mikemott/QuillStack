//
//  CoreDataStack.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()

    private init() {}

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "QuillStack")

        // Enable encryption and file protection
        let description = container.persistentStoreDescriptions.first
        description?.setOption(
            FileProtectionType.complete as NSObject,
            forKey: NSPersistentStoreFileProtectionKey
        )

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production, handle this more gracefully
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // Automatically merge changes from parent
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    // MARK: - Background Context

    /// Creates a new background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Save Context

    /// Saves the context if it has changes
    func save(context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    /// Saves the main view context
    func saveViewContext() throws {
        try save(context: persistentContainer.viewContext)
    }

    // MARK: - Batch Operations

    /// Performs a batch delete request
    func batchDelete(fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let context = persistentContainer.viewContext
        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult

        guard let objectIDs = result?.result as? [NSManagedObjectID] else { return }

        let changes: [AnyHashable: Any] = [
            NSDeletedObjectsKey: objectIDs
        ]

        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: changes,
            into: [context]
        )
    }
}
