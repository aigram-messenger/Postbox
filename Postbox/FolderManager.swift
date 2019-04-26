//
//  FolderManager.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

final class FolderManager {

    private var cachedFolders: [Folder] = [] {
        didSet {
            updateClosure?(folders)
        }
    }

    private var cachedLastMessages: [Folder.Id: Message] = [:] {
        didSet {
            updateClosure?(folders)
        }
    }

    var folders: [Folder] {
        return cachedFolders
            .map {
                $0.lastMessage = cachedLastMessages[$0.folderId]
                return $0
            }
            .sorted {
                guard
                    let leftTimestamp = $0.lastMessage?.timestamp,
                    let rightTimestamp = $1.lastMessage?.timestamp
                else { return false }

                return leftTimestamp < rightTimestamp
            }
    }

    private let folderStorage: FolderStorage = .shared
    private let idGenerator: IdGenerator = .shared

    static var shared: FolderManager = .init()

    var updateClosure: (([Folder]) -> Void)? {
        didSet {
            updateClosure?(folders)
        }
    }

    private init() {
        folderStorage.folderListUpdate = { [weak self] in
            self?.cachedFolders = $0
        }
    }

    func createFolder(with name: String, peerIds: [PeerId]) {
        let result = folderStorage.create(
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
        fatalError("\(#function) is not implemented.")
    }

    func update(folder: Folder) {
        fatalError("\(#function) is not implemented.")
    }

    func process(messages: [(message: Message, chat: Peer)]) {
        var filteredMessages: [PeerId: (message: Message, chat: Peer)] =
            messages.reduce(into: [:]) {
            if let oldValue = $0[$1.chat.id] {
                guard oldValue.message.timestamp < $1.message.timestamp else { return }
                $0[$1.chat.id] = $1
            } else {
                $0[$1.chat.id] = $1
            }
        }

        let updatedFolders: [Folder] = folderStorage.getAllFolders()
            .compactMap { folder in
                folder.peerIds
                    .lazy
                    .compactMap { filteredMessages[$0]?.message }
                    .reduce(folder.lastMessage) { prev, new in
                        prev.map { $0.timestamp < new.timestamp ? new : $0 } ?? new
                    }
                    .map {
                        folder.lastMessage = $0
                        return folder
                    }
            }

        updatedFolders.forEach {
            cachedLastMessages[$0.folderId] = $0.lastMessage?.withUpdatedPeer($0)
        }
    }

}

private extension Message {

    func withUpdatedPeer(_ peer: Peer) -> Message {
        let id = MessageId(peerId: peer.id, namespace: self.id.namespace, id: self.id.id)
        var peers = self.peers
        peers[peer.id] = peer

        return Message(
            stableId: self.stableId,
            stableVersion: self.stableVersion,
            id: id,
            globallyUniqueId: self.globallyUniqueId,
            groupingKey: self.groupingKey,
            groupInfo: self.groupInfo,
            timestamp: self.timestamp,
            flags: self.flags,
            tags: self.tags,
            globalTags: self.globalTags,
            localTags: self.localTags,
            forwardInfo: self.forwardInfo,
            author: self.author,
            text: self.text,
            attributes: self.attributes,
            media: self.media,
            peers: peers,
            associatedMessages: self.associatedMessages,
            associatedMessageIds: self.associatedMessageIds
        )
    }

}
