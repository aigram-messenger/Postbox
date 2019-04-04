import Foundation

public struct ChatListEntryMessageTagSummaryComponent {
    public let tag: MessageTags
    public let namespace: MessageId.Namespace
    
    public init(tag: MessageTags, namespace: MessageId.Namespace) {
        self.tag = tag
        self.namespace = namespace
    }
}

public struct ChatListEntryPendingMessageActionsSummaryComponent {
    public let type: PendingMessageActionType
    public let namespace: MessageId.Namespace
    
    public init(type: PendingMessageActionType, namespace: MessageId.Namespace) {
        self.type = type
        self.namespace = namespace
    }
}

public struct ChatListEntrySummaryComponents {
    public let tagSummary: ChatListEntryMessageTagSummaryComponent?
    public let actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent?
    
    public init(tagSummary: ChatListEntryMessageTagSummaryComponent? = nil, actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent? = nil) {
        self.tagSummary = tagSummary
        self.actionsSummary = actionsSummary
    }
}

public struct ChatListMessageTagSummaryInfo: Equatable {
    public let tagSummaryCount: Int32?
    public let actionsSummaryCount: Int32?
    
    public init(tagSummaryCount: Int32? = nil, actionsSummaryCount: Int32? = nil) {
        self.tagSummaryCount = tagSummaryCount
        self.actionsSummaryCount = actionsSummaryCount
    }
    
    public static func ==(lhs: ChatListMessageTagSummaryInfo, rhs: ChatListMessageTagSummaryInfo) -> Bool {
        return lhs.tagSummaryCount == rhs.tagSummaryCount && lhs.actionsSummaryCount == rhs.actionsSummaryCount
    }
}

public struct GroupReferenceUnreadCounters: Equatable {
    public let unreadCount: Int32
    public let unreadMutedCount: Int32
    
    init(_ counters: ChatListGroupReferenceUnreadCounters) {
        let (unreadCount, unreadMutedCount) = counters.getCounters()
        self.unreadCount = unreadCount
        self.unreadMutedCount = unreadMutedCount
    }
    
    public static func ==(lhs: GroupReferenceUnreadCounters, rhs: GroupReferenceUnreadCounters) -> Bool {
        return lhs.unreadCount == rhs.unreadCount && lhs.unreadMutedCount == rhs.unreadMutedCount
    }
}

public enum ChatListEntry: Comparable {
    case MessageEntry(ChatListIndex, Message?, CombinedPeerReadState?, PeerNotificationSettings?, PeerChatListEmbeddedInterfaceState?, RenderedPeer, ChatListMessageTagSummaryInfo)
    case HoleEntry(ChatListHole)
    case GroupReferenceEntry(PeerGroupId, ChatListIndex, Message?, [Peer], GroupReferenceUnreadCounters)
    
    public var index: ChatListIndex {
        switch self {
            case let .MessageEntry(index, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            case let .GroupReferenceEntry(_, index, _, _, _):
                return index
        }
    }

    public static func ==(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
        switch lhs {
            case let .MessageEntry(lhsIndex, lhsMessage, lhsReadState, lhsSettings, lhsEmbeddedState, lhsPeer, lhsInfo):
                switch rhs {
                    case let .MessageEntry(rhsIndex, rhsMessage, rhsReadState, rhsSettings, rhsEmbeddedState, rhsPeer, rhsInfo):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsReadState != rhsReadState {
                            return false
                        }
                        if lhsMessage?.stableVersion != rhsMessage?.stableVersion {
                            return false
                        }
                        if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                            if !lhsSettings.isEqual(to: rhsSettings) {
                                return false
                            }
                        } else if (lhsSettings != nil) != (rhsSettings != nil) {
                            return false
                        }
                        if let lhsEmbeddedState = lhsEmbeddedState, let rhsEmbeddedState = rhsEmbeddedState {
                            if !lhsEmbeddedState.isEqual(to: rhsEmbeddedState) {
                                return false
                            }
                        } else if (lhsEmbeddedState != nil) != (rhsEmbeddedState != nil) {
                            return false
                        }
                        if lhsPeer != rhsPeer {
                            return false
                        }
                        if lhsInfo != rhsInfo {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .HoleEntry(hole):
                if case .HoleEntry(hole) = rhs {
                    return true
                } else {
                    return false
                }
            case let .GroupReferenceEntry(lhsGroupId, lhsIndex, lhsMessage, lhsTopPeers, lhsUnreadCounters):
                if case let .GroupReferenceEntry(rhsGroupId, rhsIndex, rhsMessage, rhsTopPeers, rhsUnreadCounters) = rhs, lhsGroupId == rhsGroupId, lhsIndex == rhsIndex {
                    if lhsMessage?.stableVersion != rhsMessage?.stableVersion {
                        return false
                    }
                    if lhsTopPeers.count != rhsTopPeers.count {
                        for i in 0 ..< lhsTopPeers.count {
                            if lhsTopPeers[i].id != rhsTopPeers[i].id {
                                return false
                            }
                        }
                    }
                    if lhsUnreadCounters != rhsUnreadCounters {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }

    public static func <(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

enum MutableChatListEntry: Equatable {
    case IntermediateMessageEntry(ChatListIndex, IntermediateMessage?, CombinedPeerReadState?, PeerChatListEmbeddedInterfaceState?)
    case MessageEntry(ChatListIndex, Message?, CombinedPeerReadState?, PeerNotificationSettings?, PeerChatListEmbeddedInterfaceState?, RenderedPeer, ChatListMessageTagSummaryInfo)
    case HoleEntry(ChatListHole)
    case IntermediateGroupReferenceEntry(PeerGroupId, ChatListIndex, ChatListGroupReferenceUnreadCounters?)
    case GroupReferenceEntry(PeerGroupId, ChatListIndex, Message?, ChatListGroupReferenceTopPeers, ChatListGroupReferenceUnreadCounters)
    
    init(_ intermediateEntry: ChatListIntermediateEntry, readStateTable: MessageHistoryReadStateTable) {
        switch intermediateEntry {
            case let .message(index, message, embeddedState):
                self = .IntermediateMessageEntry(index, message, readStateTable.getCombinedState(index.messageIndex.id.peerId), embeddedState)
            case let .hole(hole):
                self = .HoleEntry(hole)
            case let .groupReference(groupId, index):
                self = .IntermediateGroupReferenceEntry(groupId, index, nil)
        }
    }
    
    var index: ChatListIndex {
        switch self {
            case let .IntermediateMessageEntry(index, _, _, _):
                return index
            case let .MessageEntry(index, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            case let .IntermediateGroupReferenceEntry(_, index, _):
                return index
            case let .GroupReferenceEntry(_, index, _, _, _):
                return index
        }
    }

    static func ==(lhs: MutableChatListEntry, rhs: MutableChatListEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        
        switch lhs {
            case .IntermediateMessageEntry:
                switch rhs {
                    case .IntermediateMessageEntry:
                        return true
                    default:
                        return false
                }
            case .MessageEntry:
                switch rhs {
                    case .MessageEntry:
                        return true
                    default:
                        return false
                }
            case .HoleEntry:
                switch rhs {
                    case .HoleEntry:
                        return true
                    default:
                        return false
                }
            case .IntermediateGroupReferenceEntry:
                switch rhs {
                    case .IntermediateGroupReferenceEntry:
                        return true
                    default:
                        return false
                }
            case .GroupReferenceEntry:
                switch rhs {
                    case .GroupReferenceEntry:
                        return true
                    default:
                        return false
                }
        }
    }
}

final class MutableChatListViewReplayContext {
    var invalidEarlier: Bool = false
    var invalidLater: Bool = false
    var removedEntries: Bool = false
    
    func empty() -> Bool {
        return !self.removedEntries && !invalidEarlier && !invalidLater
    }
}

private enum ChatListEntryType {
    case message
    case hole
    case groupReference
}

private func updateMessagePeers(_ message: Message, updatedPeers: [PeerId: Peer]) -> Message? {
    var updated = false
    for (peerId, currentPeer) in message.peers {
        if let updatedPeer = updatedPeers[peerId], !arePeersEqual(currentPeer, updatedPeer) {
            updated = true
            break
        }
    }
    if updated {
        var peers = SimpleDictionary<PeerId, Peer>()
        for (peerId, currentPeer) in message.peers {
            if let updatedPeer = updatedPeers[peerId] {
                peers[peerId] = updatedPeer
            } else {
                peers[peerId] = currentPeer
            }
        }
        return Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
    }
    return nil
}

private func updatedRenderedPeer(_ renderedPeer: RenderedPeer, updatedPeers: [PeerId: Peer]) -> RenderedPeer? {
    var updated = false
    for (peerId, currentPeer) in renderedPeer.peers {
        if let updatedPeer = updatedPeers[peerId], !arePeersEqual(currentPeer, updatedPeer) {
            updated = true
            break
        }
    }
    if updated {
        var peers = SimpleDictionary<PeerId, Peer>()
        for (peerId, currentPeer) in renderedPeer.peers {
            if let updatedPeer = updatedPeers[peerId] {
                peers[peerId] = updatedPeer
            } else {
                peers[peerId] = currentPeer
            }
        }
        return RenderedPeer(peerId: renderedPeer.peerId, peers: peers)
    }
    return nil
}

private func isIncluded(_ entry: MutableChatListEntry, with filter: GroupingFilter) -> Bool {
    switch entry {
    case .IntermediateMessageEntry, .HoleEntry, .IntermediateGroupReferenceEntry:
        return true
    case .GroupReferenceEntry:
        print(entry)
        return true
    case let .MessageEntry(_, _, _, _, _, renderedPeer, _):
        // TODO: Что будет, если пользователь не подтянут в кеш? Как это фильтровать?
        if let peer = renderedPeer.peer {
            return filter.isIncluded(peer)
        } else {
            return filter.isIncluded(renderedPeer.peerId)
        }
    }
}

private func filtered(entries: [MutableChatListEntry], with filter: GroupingFilter) -> [MutableChatListEntry] {
    return entries.filter {
        isIncluded($0, with: filter)
    }
}

private func filtered(entry: MutableChatListEntry?, with filter: GroupingFilter) -> MutableChatListEntry? {
    return entry.flatMap {
        isIncluded($0, with: filter) ? $0 : nil
    }
}

final class MutableChatListView {
    let groupId: PeerGroupId?
    private let summaryComponents: ChatListEntrySummaryComponents
    fileprivate var additionalItemIds: Set<PeerId>
    fileprivate var additionalItemEntries: [MutableChatListEntry]
    fileprivate var earlier: MutableChatListEntry?
    fileprivate var later: MutableChatListEntry?
    fileprivate var entries: [MutableChatListEntry]
    private var count: Int

    // FIXME: Move to `ChatListView`.
//    fileprivate let filter: GroupingFilter

    init(postbox: Postbox, groupId: PeerGroupId?, earlier: MutableChatListEntry?, entries: [MutableChatListEntry], later: MutableChatListEntry?, count: Int, summaryComponents: ChatListEntrySummaryComponents/*, filter: GroupingFilter*/) {
        self.groupId = groupId

        self.earlier = earlier//filtered(entry: earlier, with: filter)
        self.entries = entries//filtered(entries: entries, with: filter)
        self.later = later//filtered(entry: later, with: filter)

        self.count = count
        self.summaryComponents = summaryComponents
        self.additionalItemEntries = []
//        self.filter = filter
        if groupId == nil {
            let itemIds = postbox.additionalChatListItemsTable.get()
            self.additionalItemIds = []
            for peerId in itemIds {
                if let entry = postbox.chatListTable.getStandalone(peerId: peerId, messageHistoryTable: postbox.messageHistoryTable) {
                    let entry = MutableChatListEntry(entry, readStateTable: postbox.readStateTable)
//                    if isIncluded(entry, with: filter) {
                        self.additionalItemEntries.append(entry)
                        additionalItemIds.insert(peerId)
//                    }
                }
            }
        } else {
            self.additionalItemIds = Set()
        }
    }
    
    func refreshDueToExternalTransaction(postbox: Postbox) -> Bool {
        var index = ChatListIndex.absoluteUpperBound
        if !self.entries.isEmpty && self.later != nil {
            index = self.entries[self.entries.count / 2].index
        }

        let (entries, earlier, later) = postbox.fetchAroundChatEntries(groupId: self.groupId, index: index, count: self.entries.count)
//        let (_entries, _earlier, _later) = postbox.fetchAroundChatEntries(groupId: self.groupId, index: index, count: self.entries.count)

//        let entries = filtered(entries: _entries, with: filter)
//        let earlier = filtered(entry: _earlier, with: filter)
//        let later = filtered(entry: _later, with: filter)

        if entries != self.entries || earlier != self.earlier || later != self.later {
            self.entries = entries
            self.earlier = earlier
            self.later = later
            return true
        } else {
            return false
        }
    }
    
    func replay(postbox: Postbox, operations: [WrappedPeerGroupId: [ChatListOperation]], updatedPeerNotificationSettings: [PeerId: PeerNotificationSettings], updatedPeers: [PeerId: Peer], transaction: PostboxTransaction, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        var cachedGroupCounters: [PeerGroupId: ChatListGroupReferenceUnreadCounters] = [:]
        
        if !transaction.alteredInitialPeerCombinedReadStates.isEmpty || !transaction.currentUpdatedPeerNotificationSettings.isEmpty || !transaction.currentInitialPeerGroupIdsBeforeUpdate.isEmpty {
            for entry in self.entries {
                switch entry {
                    case let .GroupReferenceEntry(groupId, _, _, _, counters):
                        cachedGroupCounters[groupId] = counters
                    case let .IntermediateGroupReferenceEntry(groupId, _, counters):
                        if let counters = counters {
                            cachedGroupCounters[groupId] = counters
                        }
                    default:
                        break
                }
            }
        }
        
        if let groupOperations = operations[WrappedPeerGroupId(groupId: self.groupId)] {
            for operation in groupOperations {
                switch operation {
                    case let .InsertEntry(index, message, combinedReadState, embeddedState):
                        if self.add(.IntermediateMessageEntry(index, message, combinedReadState, embeddedState)) {
                            hasChanges = true
                        }
                    case let .InsertHole(index):
                        if self.add(.HoleEntry(index)) {
                            hasChanges = true
                        }
                    case let .InsertGroupReference(groupId, index):
                        if self.add(.IntermediateGroupReferenceEntry(groupId, index, cachedGroupCounters[groupId] ?? ChatListGroupReferenceUnreadCounters(postbox: postbox, groupId: groupId))) {
                            hasChanges = true
                        }
                    case let .RemoveEntry(indices):
                        if self.remove(Set(indices), type: .message, context: context) {
                            hasChanges = true
                        }
                    case let .RemoveHoles(indices):
                        if self.remove(Set(indices), type: .hole, context: context) {
                            hasChanges = true
                        }
                    case let .RemoveGroupReferences(indices):
                        if self.remove(Set(indices), type: .groupReference, context: context) {
                            hasChanges = true
                        }
                }
            }
        }
        
        for i in 0 ..< self.entries.count {
            switch self.entries[i] {
                case let .GroupReferenceEntry(groupId, _, _, topPeers, counters):
                    if topPeers.replay(postbox: postbox, transaction: transaction) {
                        hasChanges = true
                    }
                    if cachedGroupCounters[groupId] != nil {
                        if counters.replay(postbox: postbox, transaction: transaction) {
                            hasChanges = true
                        }
                    }
                case let .IntermediateGroupReferenceEntry(groupId, _, counters):
                    if let counters = counters {
                        if cachedGroupCounters[groupId] != nil {
                            if counters.replay(postbox: postbox, transaction: transaction) {
                                hasChanges = true
                            }
                        }
                    }
                default:
                    break
            }
        }
        
        if !updatedPeerNotificationSettings.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(index, message, readState, _, embeddedState, peer, summaryInfo):
                        var notificationSettingsPeerId = peer.peerId
                        if let peer = peer.peers[peer.peerId], let associatedPeerId = peer.associatedPeerId {
                            notificationSettingsPeerId = associatedPeerId
                        }
                        if let settings = updatedPeerNotificationSettings[notificationSettingsPeerId] {
                            self.entries[i] = .MessageEntry(index, message, readState, settings, embeddedState, peer, summaryInfo)
                            hasChanges = true
                        }
                    default:
                        continue
                }
            }
        }
        if !updatedPeers.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(index, message, readState, settings, embeddedState, peer, summaryInfo):
                        var updatedMessage: Message?
                        if let message = message {
                            updatedMessage = updateMessagePeers(message, updatedPeers: updatedPeers)
                        }
                        let updatedPeer = updatedRenderedPeer(peer, updatedPeers: updatedPeers)
                        if updatedMessage != nil || updatedPeer != nil {
                            self.entries[i] = .MessageEntry(index, updatedMessage ?? message, readState, settings, embeddedState, updatedPeer ?? peer, summaryInfo)
                            hasChanges = true
                        }
                    default:
                        continue
                }
            }
        }
        if !transaction.currentUpdatedMessageTagSummaries.isEmpty || !transaction.currentUpdatedMessageActionsSummaries.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .MessageEntry(index, message, readState, settings, embeddedState, peer, currentSummary):
                        var updatedTagSummaryCount: Int32?
                        var updatedActionsSummaryCount: Int32?
                        
                        if let tagSummary = self.summaryComponents.tagSummary {
                            let key = MessageHistoryTagsSummaryKey(tag: tagSummary.tag, peerId: index.messageIndex.id.peerId, namespace: tagSummary.namespace)
                            if let summary = transaction.currentUpdatedMessageTagSummaries[key] {
                                updatedTagSummaryCount = summary.count
                            }
                        }
                        
                        if let actionsSummary = self.summaryComponents.actionsSummary {
                            let key = PendingMessageActionsSummaryKey(type: actionsSummary.type, peerId: index.messageIndex.id.peerId, namespace: actionsSummary.namespace)
                            if let count = transaction.currentUpdatedMessageActionsSummaries[key] {
                                updatedActionsSummaryCount = count
                            }
                        }
                        
                        if updatedTagSummaryCount != nil || updatedActionsSummaryCount != nil {
                            let summaryInfo = ChatListMessageTagSummaryInfo(tagSummaryCount: updatedTagSummaryCount ?? currentSummary.tagSummaryCount, actionsSummaryCount: updatedActionsSummaryCount ?? currentSummary.actionsSummaryCount)
                            
                            self.entries[i] = .MessageEntry(index, message, readState, settings, embeddedState, peer, summaryInfo)
                            hasChanges = true
                        }
                    default:
                        continue
                }
            }
        }
        var updateAdditionalItems = false
        if let itemIds = transaction.replacedAdditionalChatListItems {
            self.additionalItemIds = Set(itemIds)
            updateAdditionalItems = true
        }
        for peerId in self.additionalItemIds {
            if transaction.currentOperationsByPeerId[peerId] != nil {
                updateAdditionalItems = true
            }
            if transaction.currentUpdatedPeers[peerId] != nil {
                updateAdditionalItems = true
            }
            if transaction.currentUpdatedChatListInclusions[peerId] != nil {
                updateAdditionalItems = true
            }
        }
        if updateAdditionalItems {
            self.additionalItemEntries.removeAll()
            for peerId in postbox.additionalChatListItemsTable.get() {
                if let entry = postbox.chatListTable.getStandalone(peerId: peerId, messageHistoryTable: postbox.messageHistoryTable) {
                    let entry = MutableChatListEntry(entry, readStateTable: postbox.readStateTable)
//                    if isIncluded(entry, with: filter) {
                        self.additionalItemEntries.append(entry)
//                    }
                }
            }
            hasChanges = true
        }
        return hasChanges
    }
    
    func add(_ entry: MutableChatListEntry) -> Bool {
//        guard isIncluded(entry, with: filter) else {
//            return false
//        }

        if self.entries.count == 0 {
            self.entries.append(entry)
            return true
        } else {
            let first = self.entries[self.entries.count - 1]
            let last = self.entries[0]
            
            let next = self.later
            
            if entry.index < last.index {
                if self.earlier == nil || self.earlier!.index < entry.index {
                    if self.entries.count < self.count {
                        self.entries.insert(entry, at: 0)
                    } else {
                        self.earlier = entry
                    }
                    return true
                } else {
                    return false
                }
            } else if entry.index > first.index {
                if next != nil && entry.index > next!.index {
                    if self.later == nil || self.later!.index > entry.index {
                        if self.entries.count < self.count {
                            self.entries.append(entry)
                        } else {
                            self.later = entry
                        }
                        return true
                    } else {
                        return false
                    }
                } else {
                    self.entries.append(entry)
                    if self.entries.count > self.count {
                        self.earlier = self.entries[0]
                        self.entries.remove(at: 0)
                    }
                    return true
                }
            } else if entry != last && entry != first {
                var i = self.entries.count
                while i >= 1 {
                    if self.entries[i - 1].index < entry.index {
                        break
                    }
                    i -= 1
                }
                self.entries.insert(entry, at: i)
                if self.entries.count > self.count {
                    self.earlier = self.entries[0]
                    self.entries.remove(at: 0)
                }
                return true
            } else {
                return false
            }
        }
    }
    
    private func remove(_ indices: Set<ChatListIndex>, type: ChatListEntryType, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        if let earlier = self.earlier, indices.contains(earlier.index) {
            var match = false
            switch earlier {
                case .HoleEntry:
                    match = type == .hole
                case .IntermediateMessageEntry, .MessageEntry:
                    match = type == .message
                case .IntermediateGroupReferenceEntry, .GroupReferenceEntry:
                    match = type == .groupReference
            }
            if match {
                context.invalidEarlier = true
                hasChanges = true
            }
        }
        
        if let later = self.later, indices.contains(later.index) {
            var match = false
            switch later {
                case .HoleEntry:
                    match = type == .hole
                case .IntermediateMessageEntry, .MessageEntry:
                    match = type == .message
                case .IntermediateGroupReferenceEntry, .GroupReferenceEntry:
                    match = type == .groupReference
            }
            if match {
                context.invalidLater = true
                hasChanges = true
            }
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                if indices.contains(self.entries[i].index) {
                    var match = false
                    switch self.entries[i] {
                        case .HoleEntry:
                            match = type == .hole
                        case .IntermediateMessageEntry, .MessageEntry:
                            match = type == .message
                        case .IntermediateGroupReferenceEntry, .GroupReferenceEntry:
                            match = type == .groupReference
                    }
                    if match {
                        self.entries.remove(at: i)
                        context.removedEntries = true
                        hasChanges = true
                    }
                }
                i -= 1
            }
        }
        
        return hasChanges
    }
    
    func complete(postbox: Postbox, context: MutableChatListViewReplayContext) {
        if context.removedEntries {
            var addedEntries: [MutableChatListEntry] = []
            
            var latestAnchor: ChatListIndex?
            if let last = self.entries.last {
                latestAnchor = last.index
            }
            
            if latestAnchor == nil {
                if let later = self.later {
                    latestAnchor = later.index
                }
            }
            
            if let later = self.later {
                addedEntries += postbox.fetchLaterChatEntries(groupId: self.groupId, index: later.index.predecessor, count: self.count)
//                addedEntries += filtered(
//                    entries: postbox.fetchLaterChatEntries(groupId: self.groupId, index: later.index.predecessor, count: self.count),
//                    with: filter
//                )
            }
            if let earlier = self.earlier {
                addedEntries += postbox.fetchEarlierChatEntries(groupId: self.groupId, index: earlier.index.successor, count: self.count)
//                addedEntries += filtered(
//                    entries: postbox.fetchEarlierChatEntries(groupId: self.groupId, index: earlier.index.successor, count: self.count),
//                    with: filter
//                )
            }
            
            addedEntries += self.entries
            addedEntries.sort(by: { $0.index < $1.index })
            var i = addedEntries.count - 1
            while i >= 1 {
                if addedEntries[i].index.messageIndex.id == addedEntries[i - 1].index.messageIndex.id {
                    addedEntries.remove(at: i)
                }
                i -= 1
            }
            self.entries = []
            
            var anchorIndex = addedEntries.count - 1
            if let latestAnchor = latestAnchor {
                var i = addedEntries.count - 1
                while i >= 0 {
                    if addedEntries[i].index <= latestAnchor {
                        anchorIndex = i
                        break
                    }
                    i -= 1
                }
            }
            
            self.later = nil
            if anchorIndex + 1 < addedEntries.count {
                self.later = addedEntries[anchorIndex + 1]
            }
            
            i = anchorIndex
            while i >= 0 && i > anchorIndex - self.count {
                self.entries.insert(addedEntries[i], at: 0)
                i -= 1
            }
            
            self.earlier = nil
            if anchorIndex - self.count >= 0 {
                self.earlier = addedEntries[anchorIndex - self.count]
            }
        } else {
            if context.invalidEarlier {
                var earlyId: ChatListIndex?
                let i = 0
                if i < self.entries.count {
                    earlyId = self.entries[i].index
                }

                let earlierEntries = postbox.fetchEarlierChatEntries(groupId: self.groupId, index: earlyId, count: 1)
//                let earlierEntries = filtered(
//                    entries: postbox.fetchEarlierChatEntries(groupId: self.groupId, index: earlyId, count: 1),
//                    with: filter
//                )
                self.earlier = earlierEntries.first
            }
            
            if context.invalidLater {
                var laterId: ChatListIndex?
                let i = self.entries.count - 1
                if i >= 0 {
                    laterId = self.entries[i].index
                }

                let laterEntries = postbox.fetchLaterChatEntries(groupId: self.groupId, index: laterId, count: 1)
//                let laterEntries = filtered(
//                    entries: postbox.fetchLaterChatEntries(groupId: self.groupId, index: laterId, count: 1),
//                    with: filter
//                )
                self.later = laterEntries.first
            }
        }
    }
    
    func firstHole() -> ChatListHole? {
        for entry in self.entries {
            if case let .HoleEntry(hole) = entry {
                return hole
            }
        }
        
        return nil
    }
    
    private func renderEntry(_ entry: MutableChatListEntry, postbox: Postbox, renderMessage: (IntermediateMessage) -> Message, getPeer: (PeerId) -> Peer?, getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?) -> MutableChatListEntry? {
        switch entry {
            case let .IntermediateMessageEntry(index, message, combinedReadState, embeddedState):
                let renderedMessage: Message?
                if let message = message {
                    renderedMessage = renderMessage(message)
                } else {
                    renderedMessage = nil
                }
                var peers = SimpleDictionary<PeerId, Peer>()
                var notificationSettings: PeerNotificationSettings?
                if let peer = getPeer(index.messageIndex.id.peerId) {
                    peers[peer.id] = peer
                    if let associatedPeerId = peer.associatedPeerId {
                        if let associatedPeer = getPeer(associatedPeerId) {
                            peers[associatedPeer.id] = associatedPeer
                        }
                        notificationSettings = getPeerNotificationSettings(associatedPeerId)
                    } else {
                        notificationSettings = getPeerNotificationSettings(index.messageIndex.id.peerId)
                    }
                }
                
                var tagSummaryCount: Int32?
                var actionsSummaryCount: Int32?
                
                if let tagSummary = self.summaryComponents.tagSummary {
                    let key = MessageHistoryTagsSummaryKey(tag: tagSummary.tag, peerId: index.messageIndex.id.peerId, namespace: tagSummary.namespace)
                    if let summary = postbox.messageHistoryTagsSummaryTable.get(key) {
                        tagSummaryCount = summary.count
                    }
                }
                
                if let actionsSummary = self.summaryComponents.actionsSummary {
                    let key = PendingMessageActionsSummaryKey(type: actionsSummary.type, peerId: index.messageIndex.id.peerId, namespace: actionsSummary.namespace)
                    actionsSummaryCount = postbox.pendingMessageActionsMetadataTable.getCount(.peerNamespaceAction(key.peerId, key.namespace, key.type))
                }
                
                return .MessageEntry(index, renderedMessage, combinedReadState, notificationSettings, embeddedState, RenderedPeer(peerId: index.messageIndex.id.peerId, peers: peers), ChatListMessageTagSummaryInfo(tagSummaryCount: tagSummaryCount, actionsSummaryCount: actionsSummaryCount))
            case let .IntermediateGroupReferenceEntry(groupId, index, counters):
                let message = postbox.messageHistoryTable.getMessage(index.messageIndex).flatMap(postbox.renderIntermediateMessage)
               return .GroupReferenceEntry(groupId, index, message, ChatListGroupReferenceTopPeers(postbox: postbox, groupId: groupId), counters ?? ChatListGroupReferenceUnreadCounters(postbox: postbox, groupId: groupId))
            default:
                return nil
        }
    }
    
    func render(postbox: Postbox, renderMessage: (IntermediateMessage) -> Message, getPeer: (PeerId) -> Peer?, getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?) {
        entries = entries
            .compactMap {
                renderEntry(
                    $0,
                    postbox: postbox,
                    renderMessage: renderMessage,
                    getPeer: getPeer,
                    getPeerNotificationSettings: getPeerNotificationSettings
                ) ?? $0
            }
//            .filter { isIncluded($0, with: filter) }

        additionalItemEntries = additionalItemEntries
            .compactMap {
                renderEntry(
                    $0,
                    postbox: postbox,
                    renderMessage: renderMessage,
                    getPeer: getPeer,
                    getPeerNotificationSettings: getPeerNotificationSettings
                ) ?? $0
            }
//            .filter { isIncluded($0, with: filter) }
    }
}

public final class ChatListView {
    public let groupId: PeerGroupId?
    public let additionalItemEntries: [ChatListEntry]
    public let entries: [ChatListEntry]
    public let earlierIndex: ChatListIndex?
    public let laterIndex: ChatListIndex?
    
    init(_ mutableView: MutableChatListView, filter: ([MutableChatListEntry]) -> [MutableChatListEntry]) {
        self.groupId = mutableView.groupId
        
        var entries: [ChatListEntry] = []
        for entry in filter(mutableView.entries) {
            switch entry {
                case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo):
                    entries.append(.MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo))
                case let .HoleEntry(hole):
                    entries.append(.HoleEntry(hole))
                case let .GroupReferenceEntry(groupId, index, message, topPeers, counters):
                    entries.append(.GroupReferenceEntry(groupId, index, message, topPeers.getPeers(), GroupReferenceUnreadCounters(counters)))
                case .IntermediateMessageEntry:
                    assertionFailure()
                case .IntermediateGroupReferenceEntry:
                    assertionFailure()
            }
        }
        self.entries = entries
        // TODO: Нужно ли фильтровать и их? А если нужно, то как?
        self.earlierIndex = mutableView.earlier?.index
        self.laterIndex = mutableView.later?.index

        var additionalItemEntries: [ChatListEntry] = []
        for entry in filter(mutableView.additionalItemEntries) {
            switch entry {
                case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo):
                    additionalItemEntries.append(.MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo))
                case .HoleEntry:
                    assertionFailure()
                case .GroupReferenceEntry:
                    assertionFailure()
                case .IntermediateMessageEntry:
                    assertionFailure()
                case .IntermediateGroupReferenceEntry:
                    assertionFailure()
            }
        }
        
        self.additionalItemEntries = additionalItemEntries
    }
}
