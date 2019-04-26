//
//  Folder.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

public let FolderPeerIdNamespace: Int32 = 100

public final class Folder {
    public typealias Id = Int32

    public let folderId: Id
    public var name: String
    public var peerIds: Set<PeerId>
    public var lastMessage: Message?

    init(
        id: Id,
        name: String,
        peerIds: [PeerId]
    ) {
        self.folderId = id
        self.name = name
        self.peerIds = Set(peerIds)
    }
}

extension Folder: Peer {

    public var id: PeerId {
        return .init(namespace: FolderPeerIdNamespace, id: -folderId)
    }

    public var indexName: PeerIndexNameRepresentation {
        return .title(title: name, addressName: nil)
    }

    public var associatedPeerId: PeerId? {
        return nil
    }

    public var notificationSettingsPeerId: PeerId? {
        return nil
    }

    public func isEqual(_ other: Peer) -> Bool {
        guard let other = other as? Folder, folderId == other.folderId else {
            return false
        }
        return true
    }

    public convenience init(decoder: PostboxDecoder) {
        fatalError("Not implemented")
    }

    public func encode(_ encoder: PostboxEncoder) {
        fatalError("Not implemented")
    }    

}
