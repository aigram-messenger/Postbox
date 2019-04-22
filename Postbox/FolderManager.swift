//
//  FolderManager.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

final class FolderManager {

    private(set) var folderDescriptors: [Folder] = []

    private let folderStorage: FolderStorage = .shared
    private let idGenerator: IdGenerator = .shared

    static var shared: FolderManager = .init()

    private init() {

    }

    func createFolder(with name: String, peerIds: [PeerId]) {
        let result = folderStorage.save(
            folder: .init(
                id: idGenerator.generateId(),
                name: name,
                peerIds: peerIds
            )
        )

        if case let .failure(error) = result {
            // TODO: Handle error
            print(error)
        }
    }

    func delete(folderWithId id: Folder.Id) {
        let result = folderStorage.delete(folderWithId: id)

        if case let .failure(error) = result {
            // TODO: Handle error
            print(error)
        }
    }

    func update(folder: Folder) {
        let result = folderStorage.save(folder: folder)

        if case let .failure(error) = result {
            // TODO: Handle error
            print(error)
        }
    }

}
