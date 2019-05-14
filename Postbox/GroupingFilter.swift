//
//  GroupingFilter.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 04/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

// FIXME: Move to TelegramUI.
public enum ChatListMode {
    case standard
    case unread
    case filter(type: FilterType)
    case folders

    var isFolders: Bool {
        guard case .folders = self else { return false }
        return true
    }
}

// FIXME: Rename to something more appropriate.
enum InternalChatListMode {
    case standard
    case unread
    case filter(GroupingFilter)
    case folders([Folder])

    var isFolders: Bool {
        guard case .folders = self else { return false }
        return true
    }
}

public typealias UnreadCategoriesCallback = ([UnreadCategory]) -> Void

public enum UnreadCategory {
    case privateChats
    case unread
    case groups
    case channels
    case bots
    case all
    case folders
}

public enum FilterType {
    case privateChats
    case unread
    case groups
    case channels
    case bots
    case all
    case folder(Folder)
}

// FIXME: Temp. Remove.
extension FilterType: Hashable {
    public static func == (lhs: FilterType, rhs: FilterType) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    public var hashValue: Int {
        switch self {
        case .privateChats:
            return 0.hashValue
        case .unread:
            return 1.hashValue
        case .groups:
            return 2.hashValue
        case .channels:
            return 3.hashValue
        case .bots:
            return 4.hashValue
        case .all:
            return 5.hashValue
        case .folder:
            return 6.hashValue
        }
    }
}

public typealias IsIncludedClosure = (Peer, FilterType) -> Bool

struct GroupingFilter {

    typealias PeerFetchingClosure = (PeerId) -> Peer?

    private let fetchPeer: PeerFetchingClosure
    private let isIncluded: IsIncludedClosure

    static let empty: GroupingFilter = .init(filterType: .all, isIncluded: { _, _ in true }, fetchPeer: { _ in nil })

    let filterType: FilterType

    init(filterType: FilterType, isIncluded: @escaping IsIncludedClosure, fetchPeer: @escaping PeerFetchingClosure) {
        self.filterType = filterType
        self.isIncluded = isIncluded
        self.fetchPeer = fetchPeer
    }

    func filter(entries: [MutableChatListEntry]) -> [MutableChatListEntry] {
        return entries.filter {
            isIncluded($0)
        }
    }

    func filter(entry: MutableChatListEntry?) -> MutableChatListEntry? {
        return entry.flatMap {
            isIncluded($0) ? $0 : nil
        }
    }

    private func isIncluded(_ entry: MutableChatListEntry) -> Bool {
        switch entry {
        case .IntermediateMessageEntry, .HoleEntry, .IntermediateGroupReferenceEntry:
            return true
        case .GroupReferenceEntry:
            assertionFailure("\(entry)")
            return true
        case let .MessageEntry(_, _, _, _, _, renderedPeer, _):
            // TODO: Что будет, если пользователь не подтянут в кеш? Как это фильтровать?
            if let peer = renderedPeer.peer {
                return isIncluded(peer, filterType)
            } else {
                return fetchPeer(renderedPeer.peerId).map {
                    isIncluded($0, filterType)
                } ?? false
            }
        }
    }

}
