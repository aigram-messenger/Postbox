//
//  IdGenerator.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

private let kIdGeneratorStorage = "org.telegram.Postbox.IdGenerator"

final class IdGenerator {

    static let shared: IdGenerator = .init()

    private let storage: UserDefaults = .standard

    private lazy var lastId: Folder.Id = retrieveLastId()

    private init() { }

    func generateId() -> Folder.Id {
        let newId = lastId + 1
        store(lastId: newId)
        return newId
    }

    // MARK: - Storage access

    private func store(lastId: Folder.Id) {
        // This operation wouldn't create race condition
        // as the user wouldn't be able to create more than one folder in several seconds.
        DispatchQueue.global(qos: .utility).async { [weak storage] in
            storage?.set(lastId, forKey: kIdGeneratorStorage)
        }
    }

    private func retrieveLastId() -> Folder.Id {
        return storage.object(forKey: kIdGeneratorStorage) as? Int64 ?? 1
    }

}
