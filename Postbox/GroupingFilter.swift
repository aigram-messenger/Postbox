//
//  GroupingFilter.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 04/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

public enum FilterType {
    case privateChats
    case unread
    case groups
    case channels
    case bots
    case all
}

public typealias IsIncludedClosure = (Peer, FilterType) -> Bool

struct GroupingFilter {

    typealias PeerFetchingClosure = (PeerId) -> Peer?

    private let fetchPeer: PeerFetchingClosure
    private let isIncluded: IsIncludedClosure

    let filterType: FilterType

    init(filterType: FilterType, isIncluded: @escaping IsIncludedClosure, fetchPeer: @escaping PeerFetchingClosure) {
        self.filterType = filterType
        self.isIncluded = isIncluded
        self.fetchPeer = fetchPeer
    }

    func isIncluded(_ peer: Peer) -> Bool {
        return isIncluded(peer, filterType)
    }

    func isIncluded(_ peerId: PeerId) -> Bool {
        return fetchPeer(peerId).map {
            isIncluded($0)
        } ?? false
    }

}
