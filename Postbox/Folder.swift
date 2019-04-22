//
//  Folder.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

public struct Folder {
    typealias Id = Int64

    let id: Id
    var name: String
    var peerIds: [PeerId]

    init(
        id: Id,
        name: String,
        peerIds: [PeerId]
    ) {
        self.id = id
        self.name = name
        self.peerIds = peerIds
    }
}
