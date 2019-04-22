//
//  FolderStorage.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

//import UIKit
import CoreData

final class FolderStorage {

    var folderListUpdate: (([Folder]) -> Void)?

    static var shared: FolderStorage = .init()

    private lazy var persistenceContainer: NSPersistentContainer = {
        let modelName = "ManagedFolder"
        guard let modelUrl = Bundle(for: type(of: self)).url(forResource: modelName, withExtension: "momd") else {
            fatalError("Error loading model from bundle")
        }

        guard let model = NSManagedObjectModel(contentsOf: modelUrl) else {
            fatalError("Error initializing mom from: \(modelUrl)")
        }


        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    private var context: NSManagedObjectContext {
        return persistenceContainer.viewContext
    }

    private var cachedFolders: [ManagedFolder] = [] {
        didSet {
            folderListUpdate?(getAllFolders())
        }
    }

    private init() {
        observeAppTermination()
        fetchFromDisk()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func getAllFolders() -> [Folder] {
        return cachedFolders.map { $0.toPlainEntity() }
    }

    func save(folder: Folder) -> Result<Void> {
        _ = ManagedFolder(context: context, plainEntity: folder)

        do {
            try self.context.save()
            return .success(())
        } catch let error as NSError {
            print(error)
            return .failure(error)
        }
    }

    func delete(folderWithId id: Folder.Id) -> Result<Void> {
        guard let managedObject = cachedFolders.first(where: { $0.id == id }) else {
            return .failure(Error.failedToSave)
        }
        context.delete(managedObject)
        return .success(())
    }

    // MARK: - Initialisation

    private func fetchFromDisk() {
        let fetchRequest = NSFetchRequest<ManagedFolder>(entityName: "ManagedFolder")
        do {
            self.cachedFolders = try self.context.fetch(fetchRequest)
        } catch {
            print(error)
        }
    }

    private func observeAppTermination() {
        NotificationCenter.default.addObserver(forName: .UIApplicationWillTerminate, object: nil, queue: .main) { [weak self] notification in
            guard let context = self?.context, context.hasChanges else { return }

            do {
                try context.save()
            } catch {
                print(error)
            }
        }
    }

}

// MARK: - Types

extension FolderStorage {

    enum Result<T> {
        case success(T)
        case failure(Swift.Error)
    }

    enum Error: Swift.Error {
        case failedToSave
    }

}
