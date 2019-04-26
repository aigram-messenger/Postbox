//
//  FolderStorage.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import CoreData

final class FolderStorage {

    var folderListUpdate: (([Folder]) -> Void)? {
        didSet {
            folderListUpdate?(getAllFolders())
        }
    }

    static var shared: FolderStorage = .init()

    private lazy var persistenceContainer: NSPersistentContainer = {
        guard let container = NSPersistentContainer(type: ManagedFolder.self) else {
            fatalError("Failed to initilise container.")
        }
        
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    private var context: NSManagedObjectContext {
        return persistenceContainer.viewContext
    }

    private var cachedFolders: [Int32: ManagedFolder] = [:] {
        didSet {
            folderListUpdate?(getAllFolders())
        }
    }

    private init() {
        observeAppTermination()
        fetchFromDisk()
//        cachedFolders.forEach {
//            context.delete($1)
//        }
//        try? context.save()
//        cachedFolders.removeAll()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func getAllFolders() -> [Folder] {
        return cachedFolders.values.compactMap { $0.toPlainEntity() }
    }

    func create(folder: Folder) -> Result<Void> {
        guard cachedFolders[folder.folderId] == nil else {
            return .failure(NSError())
        }

        let managedFolder = ManagedFolder(context: context, plainEntity: folder)

        do {
            try self.context.save()
            cachedFolders[folder.folderId] = managedFolder
            return .success(())
        } catch let error as NSError {
            print(error)
            return .failure(error)
        }
    }

    func update(folder: Folder) {

    }

    func update(folders: [Folder]) {
        guard !folders.isEmpty else { return }

        var cachedFolders = self.cachedFolders
        for folder in folders {
            guard let managedFolder = cachedFolders[folder.folderId] else {
                assertionFailure("Folder \(folder.name)")
                continue
            }

            let peerIdsToDelete = managedFolder.peerIds
                .filter { !folder.peerIds.contains($0.toPlainEntity()) }

            let peerIdsToInsert = folder.peerIds
                    .lazy
                    .filter { peerId in
                        !managedFolder.peerIds.contains { $0.id == peerId.id && $0.namespace == peerId.namespace }
                    }
                    .map { ManagedPeerId(context: self.context, plainEntity: $0) }
                    .collect()

            managedFolder.name = folder.name
            managedFolder.removeFromStoredPeerIds(peerIdsToDelete as NSSet)
            managedFolder.addToStoredPeerIds(peerIdsToInsert as NSSet)
        }

        self.cachedFolders = cachedFolders
    }

    func delete(folderWithId id: Folder.Id) -> Result<Void> {
        guard let managedObject = cachedFolders[id] else {
            return .failure(Error.failedToRetrieve)
        }

        managedObject.removeFromStoredPeerIds(managedObject.storedPeerIds ?? NSSet())
        context.delete(managedObject)

        return .success(())
    }

    // MARK: - Initialisation

    private func fetchFromDisk() {
        let fetchRequest = NSFetchRequest<ManagedFolder>(entityName: String(describing: ManagedFolder.self))
        do {
            self.cachedFolders = try .init(uniqueKeysWithValues: context.fetch(fetchRequest).map { ($0.id, $0) })
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
        case failedToRetrieve
    }

}
