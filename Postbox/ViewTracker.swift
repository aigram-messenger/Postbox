import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public enum ViewUpdateType {
    case InitialUnread(MessageIndex)
    case Generic
    case FillHole(insertions: [MessageIndex: HoleFillDirection], deletions: [MessageIndex: HoleFillDirection])
    case UpdateVisible
}

final class ViewTracker {
    private let queue: Queue
    private let fetchAnchorIndex: (MessageId) -> InternalMessageHistoryAnchorIndex?
    private let renderMessage: (IntermediateMessage) -> Message
    private let getPeer: (PeerId) -> Peer?
    private let getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?
    private let getCachedPeerData: (PeerId) -> CachedPeerData?
    private let getPeerPresence: (PeerId) -> PeerPresence?
    private let getTotalUnreadState: () -> ChatListTotalUnreadState
    private let getPeerReadState: (PeerId) -> CombinedPeerReadState?
    private let operationLogGetOperations: (PeerOperationLogTag, Int32, Int) -> [PeerMergedOperationLogEntry]
    private let operationLogGetTailIndex: (PeerOperationLogTag) -> Int32?
    private let getPreferencesEntry: (ValueBoxKey) -> PreferencesEntry?
    private var filter: ([MutableChatListEntry]) -> [MutableChatListEntry]
    
    private var chatListViews = Bag<(MutableChatListView, ValuePipe<(ChatListView, ViewUpdateType)>)>()
    private var messageHistoryViews = Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>()
    private var contactPeerIdsViews = Bag<(MutableContactPeerIdsView, ValuePipe<ContactPeerIdsView>)>()
    private var contactPeersViews = Bag<(MutableContactPeersView, ValuePipe<ContactPeersView>)>()
    
    private let messageHistoryHolesView = MutableMessageHistoryHolesView()
    private let messageHistoryHolesViewSubscribers = Bag<ValuePipe<MessageHistoryHolesView>>()
    
    private let chatListHolesView = MutableChatListHolesView()
    private let chatListHolesViewSubscribers = Bag<ValuePipe<ChatListHolesView>>()
    
    private var unsentMessageView: UnsentMessageHistoryView
    private let unsendMessageIdsViewSubscribers = Bag<ValuePipe<UnsentMessageIdsView>>()
    
    private var synchronizeReadStatesView: MutableSynchronizePeerReadStatesView
    private let synchronizePeerReadStatesViewSubscribers = Bag<ValuePipe<SynchronizePeerReadStatesView>>()
    
    private var peerViews = Bag<(MutablePeerView, ValuePipe<PeerView>)>()
    
    private var unreadMessageCountsViews = Bag<(MutableUnreadMessageCountsView, ValuePipe<UnreadMessageCountsView>)>()
    private var peerMergedOperationLogViews = Bag<(MutablePeerMergedOperationLogView, ValuePipe<PeerMergedOperationLogView>)>()
    
    private let getTimestampBasedMessageAttributesHead: (UInt16) -> TimestampBasedMessageAttributesEntry?
    private var timestampBasedMessageAttributesViews = Bag<(MutableTimestampBasedMessageAttributesView, ValuePipe<TimestampBasedMessageAttributesView>)>()
    
    private var combinedViews = Bag<(CombinedMutableView, ValuePipe<CombinedView>)>()
    
    private var postboxStateViews = Bag<(MutablePostboxStateView, ValuePipe<PostboxStateView>)>()
    private var messageViews = Bag<(MutableMessageView, ValuePipe<MessageView>)>()
    private var preferencesViews = Bag<(MutablePreferencesView, ValuePipe<PreferencesView>)>()
    private var multiplePeersViews = Bag<(MutableMultiplePeersView, ValuePipe<MultiplePeersView>)>()
    private var itemCollectionsViews = Bag<(MutableItemCollectionsView, ValuePipe<ItemCollectionsView>)>()
    
    init(queue: Queue, fetchAnchorIndex: @escaping (MessageId) -> InternalMessageHistoryAnchorIndex?, renderMessage: @escaping (IntermediateMessage) -> Message, getPeer: @escaping (PeerId) -> Peer?, getPeerNotificationSettings: @escaping (PeerId) -> PeerNotificationSettings?, getCachedPeerData: @escaping (PeerId) -> CachedPeerData?, getPeerPresence: @escaping (PeerId) -> PeerPresence?, getTotalUnreadState: @escaping () -> ChatListTotalUnreadState, getPeerReadState: @escaping (PeerId) -> CombinedPeerReadState?, operationLogGetOperations: @escaping (PeerOperationLogTag, Int32, Int) -> [PeerMergedOperationLogEntry], operationLogGetTailIndex: @escaping (PeerOperationLogTag) -> Int32?, getTimestampBasedMessageAttributesHead: @escaping (UInt16) -> TimestampBasedMessageAttributesEntry?, getPreferencesEntry: @escaping (ValueBoxKey) -> PreferencesEntry?, unsentMessageIds: [MessageId], synchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation], filter: @escaping ([MutableChatListEntry]) -> [MutableChatListEntry]) {
        self.queue = queue
        self.fetchAnchorIndex = fetchAnchorIndex
        self.renderMessage = renderMessage
        self.getPeer = getPeer
        self.getPeerNotificationSettings = getPeerNotificationSettings
        self.getCachedPeerData = getCachedPeerData
        self.getPeerPresence = getPeerPresence
        self.getTotalUnreadState = getTotalUnreadState
        self.getPeerReadState = getPeerReadState
        self.operationLogGetOperations = operationLogGetOperations
        self.operationLogGetTailIndex = operationLogGetTailIndex
        self.getTimestampBasedMessageAttributesHead = getTimestampBasedMessageAttributesHead
        self.getPreferencesEntry = getPreferencesEntry
        self.filter = filter

        self.unsentMessageView = UnsentMessageHistoryView(ids: unsentMessageIds)
        self.synchronizeReadStatesView = MutableSynchronizePeerReadStatesView(operations: synchronizePeerReadStateOperations)

    }
    
    func addPostboxStateView(_ view: MutablePostboxStateView) -> (Bag<(MutablePostboxStateView, ValuePipe<PostboxStateView>)>.Index, Signal<PostboxStateView, NoError>) {
        let record = (view, ValuePipe<PostboxStateView>())
        let index = self.postboxStateViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePostboxStateView(_ index: Bag<(MutablePostboxStateView, ValuePipe<PostboxStateView>)>.Index) {
        self.postboxStateViews.remove(index)
    }
    
    func addMessageHistoryView(_ view: MutableMessageHistoryView) -> (Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index, Signal<(MessageHistoryView, ViewUpdateType), NoError>) {
        let record = (view, ValuePipe<(MessageHistoryView, ViewUpdateType)>())
        
        let index: Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index
        index = self.messageHistoryViews.add(record)
        
        self.updateTrackedHoles()
        
        return (index, record.1.signal())
    }
    
    func removeMessageHistoryView(index: Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index) {
        self.messageHistoryViews.remove(index)
        
        self.updateTrackedHoles()
    }
    
    func addChatListView(_ view: MutableChatListView) -> (Bag<(MutableChatListView, ValuePipe<(ChatListView, ViewUpdateType)>)>.Index, Signal<(ChatListView, ViewUpdateType), NoError>) {
        let record = (view, ValuePipe<(ChatListView, ViewUpdateType)>())
        let index = self.chatListViews.add(record)
        
        self.updateTrackedChatListHoles()
        
        return (index, record.1.signal())
    }
    
    func removeChatListView(_ index: Bag<(MutableChatListView, ValuePipe<ChatListView>)>.Index) {
        self.chatListViews.remove(index)
        self.updateTrackedChatListHoles()
    }
    
    func addContactPeerIdsView(_ view: MutableContactPeerIdsView) -> (Bag<(MutableContactPeerIdsView, ValuePipe<ContactPeerIdsView>)>.Index, Signal<ContactPeerIdsView, NoError>) {
        let record = (view, ValuePipe<ContactPeerIdsView>())
        let index = self.contactPeerIdsViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeContactPeerIdsView(_ index: Bag<(MutableContactPeerIdsView, ValuePipe<ContactPeerIdsView>)>.Index) {
        self.contactPeerIdsViews.remove(index)
    }
    
    func addContactPeersView(_ view: MutableContactPeersView) -> (Bag<(MutableContactPeersView, ValuePipe<ContactPeersView>)>.Index, Signal<ContactPeersView, NoError>) {
        let record = (view, ValuePipe<ContactPeersView>())
        let index = self.contactPeersViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeContactPeersView(_ index: Bag<(MutableContactPeersView, ValuePipe<ContactPeersView>)>.Index) {
        self.contactPeersViews.remove(index)
    }
    
    func updateMessageHistoryViewVisibleRange(postbox: Postbox, id: MessageHistoryViewId, earliestVisibleIndex: MessageIndex, latestVisibleIndex: MessageIndex) {
        for (mutableView, pipe) in self.messageHistoryViews.copyItems() {
            if mutableView.id == id {
                let context = MutableMessageHistoryViewReplayContext()
                var updated = false
                
                let updateType: ViewUpdateType = .UpdateVisible
                
                if mutableView.updateVisibleRange(earliestVisibleIndex: earliestVisibleIndex, latestVisibleIndex: latestVisibleIndex, context: context) {
                    mutableView.complete(postbox: postbox, context: context)
                    mutableView.incrementVersion()
                    updated = true
                }
                
                if updated {
                    mutableView.render(self.renderMessage)
                    pipe.putNext((MessageHistoryView(mutableView), updateType))
                    
                    self.updateTrackedHoles()
                }
                
                break
            }
        }
    }
    
    func addPeerView(_ view: MutablePeerView) -> (Bag<(MutablePeerView, ValuePipe<PeerView>)>.Index, Signal<PeerView, NoError>) {
        let record = (view, ValuePipe<PeerView>())
        let index = self.peerViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePeerView(_ index: Bag<(MutablePeerView, ValuePipe<Peer?>)>.Index) {
        self.peerViews.remove(index)
    }
    
    func addUnreadMessageCountsView(_ view: MutableUnreadMessageCountsView) -> (Bag<(MutableUnreadMessageCountsView, ValuePipe<UnreadMessageCountsView>)>.Index, Signal<UnreadMessageCountsView, NoError>) {
        let record = (view, ValuePipe<UnreadMessageCountsView>())
        let index = self.unreadMessageCountsViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeUnreadMessageCountsView(_ index: Bag<(MutableUnreadMessageCountsView, ValuePipe<UnreadMessageCountsView>)>.Index) {
        self.unreadMessageCountsViews.remove(index)
    }
    
    func addPeerMergedOperationLogView(_ view: MutablePeerMergedOperationLogView) -> (Bag<(MutablePeerMergedOperationLogView, ValuePipe<PeerMergedOperationLogView>)>.Index, Signal<PeerMergedOperationLogView, NoError>) {
        let record = (view, ValuePipe<PeerMergedOperationLogView>())
        let index = self.peerMergedOperationLogViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePeerMergedOperationLogView(_ index: Bag<(MutablePeerMergedOperationLogView, ValuePipe<PeerMergedOperationLogView>)>.Index) {
        self.peerMergedOperationLogViews.remove(index)
    }
    
    func addTimestampBasedMessageAttributesView(_ view: MutableTimestampBasedMessageAttributesView) -> (Bag<(MutableTimestampBasedMessageAttributesView, ValuePipe<TimestampBasedMessageAttributesView>)>.Index, Signal<TimestampBasedMessageAttributesView, NoError>) {
        let record = (view, ValuePipe<TimestampBasedMessageAttributesView>())
        let index = self.timestampBasedMessageAttributesViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeTimestampBasedMessageAttributesView(_ index: Bag<(MutableTimestampBasedMessageAttributesView, ValuePipe<TimestampBasedMessageAttributesView>)>.Index) {
        self.timestampBasedMessageAttributesViews.remove(index)
    }
    
    func addMessageView(_ view: MutableMessageView) -> (Bag<(MutableMessageView, ValuePipe<MessageView>)>.Index, Signal<MessageView, NoError>) {
        let record = (view, ValuePipe<MessageView>())
        let index = self.messageViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeMessageView(_ index: Bag<(MutableMessageView, ValuePipe<MessageView>)>.Index) {
        self.messageViews.remove(index)
    }
    
    func addPreferencesView(_ view: MutablePreferencesView) -> (Bag<(MutablePreferencesView, ValuePipe<PreferencesView>)>.Index, Signal<PreferencesView, NoError>) {
        let record = (view, ValuePipe<PreferencesView>())
        let index = self.preferencesViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePreferencesView(_ index: Bag<(MutablePreferencesView, ValuePipe<PreferencesView>)>.Index) {
        self.preferencesViews.remove(index)
    }
    
    func addMultiplePeersView(_ view: MutableMultiplePeersView) -> (Bag<(MutableMultiplePeersView, ValuePipe<MultiplePeersView>)>.Index, Signal<MultiplePeersView, NoError>) {
        let record = (view, ValuePipe<MultiplePeersView>())
        let index = self.multiplePeersViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeMultiplePeersView(_ index: Bag<(MutableMultiplePeersView, ValuePipe<MultiplePeersView>)>.Index) {
        self.multiplePeersViews.remove(index)
    }
    
    func addItemCollectionView(_ view: MutableItemCollectionsView) -> (Bag<(MutableItemCollectionsView, ValuePipe<ItemCollectionsView>)>.Index, Signal<ItemCollectionsView, NoError>) {
        let record = (view, ValuePipe<ItemCollectionsView>())
        let index = self.itemCollectionsViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeItemCollectionView(_ index: Bag<(MutableItemCollectionsView, ValuePipe<ItemCollectionsView>)>.Index) {
        self.itemCollectionsViews.remove(index)
    }
    
    func addCombinedView(_ view: CombinedMutableView) -> (Bag<(CombinedMutableView, ValuePipe<CombinedView>)>.Index, Signal<CombinedView, NoError>) {
        let record = (view, ValuePipe<CombinedView>())
        let index = self.combinedViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeCombinedView(_ index: Bag<(CombinedMutableView, ValuePipe<CombinedView>)>.Index) {
        self.combinedViews.remove(index)
    }
    
    func refreshViewsDueToExternalTransaction(postbox: Postbox, fetchUnsentMessageIds: () -> [MessageId], fetchSynchronizePeerReadStateOperations: () -> [PeerId: PeerReadStateSynchronizationOperation]) {
        var updateTrackedHoles = false
        
        for (mutableView, pipe) in self.messageHistoryViews.copyItems() {
            if mutableView.refreshDueToExternalTransaction(postbox: postbox) {
                mutableView.incrementVersion()
                
                mutableView.render(self.renderMessage)
                pipe.putNext((MessageHistoryView(mutableView), .Generic))
                
                updateTrackedHoles = true
            }
        }
        
        for (mutableView, pipe) in self.chatListViews.copyItems() {
            if mutableView.refreshDueToExternalTransaction(postbox: postbox) {
                mutableView.render(postbox: postbox, renderMessage: self.renderMessage, getPeer: { id in
                    return self.getPeer(id)
                }, getPeerNotificationSettings: self.getPeerNotificationSettings)
                pipe.putNext((ChatListView(mutableView, filter: filter), .Generic))
            }
        }
        
        if updateTrackedHoles {
            self.updateTrackedHoles()
        }
        
        if self.unsentMessageView.refreshDueToExternalTransaction(fetchUnsentMessageIds: fetchUnsentMessageIds) {
            self.unsentViewUpdated()
        }
        
        if self.synchronizeReadStatesView.refreshDueToExternalTransaction(fetchSynchronizePeerReadStateOperations: fetchSynchronizePeerReadStateOperations) {
            self.synchronizeReadStateViewUpdated()
        }
        
        for (mutableView, pipe) in self.peerViews.copyItems() {
            if mutableView.reset(postbox: postbox) {
                pipe.putNext(PeerView(mutableView))
            }
        }
    }
    
    func updateViews(postbox: Postbox, transaction: PostboxTransaction) {
        var updateTrackedHoles = false
        
        if let currentUpdatedState = transaction.currentUpdatedState {
            for (mutableView, pipe) in self.postboxStateViews.copyItems() {
                if mutableView.replay(updatedState: currentUpdatedState) {
                    pipe.putNext(PostboxStateView(mutableView))
                }
            }
        }
        
        for (mutableView, pipe) in self.messageHistoryViews.copyItems() {
            let context = MutableMessageHistoryViewReplayContext()
            var updated = false
            
            let previousPeerIds = mutableView.peerIds
        
            if mutableView.replay(postbox: postbox, transaction: transaction, updatedMedia: transaction.updatedMedia, updatedCachedPeerData: transaction.currentUpdatedCachedPeerData, context: context, renderIntermediateMessage: self.renderMessage) {
                mutableView.complete(postbox: postbox, context: context)
                mutableView.incrementVersion()
                updated = true
            }
            
            var updateType: ViewUpdateType
            switch mutableView.peerIds {
                case let .single(peerId):
                    if let filledIndices = transaction.peerIdsWithFilledHoles[peerId] {
                        updateType = .FillHole(insertions: filledIndices, deletions: transaction.removedHolesByPeerId[peerId] ?? [:])
                    } else {
                        updateType = .Generic
                    }
                case .associated, .group:
                    var holeFillDirections: [MessageIndex: HoleFillDirection] = [:]
                    var removedHolesByPeerId: [MessageIndex: HoleFillDirection] = [:]
                    
                    var ids = Set<PeerId>()
                    switch mutableView.peerIds {
                        case .single:
                            assertionFailure()
                        case let .associated(mainPeerId, associatedId):
                            ids.insert(mainPeerId)
                            if let associatedId = associatedId {
                                ids.insert(associatedId.peerId)
                            }
                        case let .group(groupId):
                            if let value = transaction.groupFeedIdsWithFilledHoles[groupId] {
                                holeFillDirections = value
                            }
                            if let value = transaction.removedHolesByPeerGroupId[groupId] {
                                removedHolesByPeerId = value
                            }
                    }
                    
                    if !ids.isEmpty {
                        for (peerId, value) in transaction.peerIdsWithFilledHoles {
                            if ids.contains(peerId) {
                                for (k, v) in value {
                                    holeFillDirections[k] = v
                                }
                            }
                        }
                        
                        for (peerId, value) in transaction.removedHolesByPeerId {
                            if ids.contains(peerId) {
                                for (k, v) in value {
                                    removedHolesByPeerId[k] = v
                                }
                            }
                        }
                    }
                    
                    if !holeFillDirections.isEmpty {
                        updateType = .FillHole(insertions: holeFillDirections, deletions: removedHolesByPeerId)
                    } else {
                        updateType = .Generic
                    }
            }
        
            if mutableView.updateAnchorIndex(self.fetchAnchorIndex) {
                updated = true
            }
        
            if mutableView.updatePeers(transaction.currentUpdatedPeers) {
                updated = true
            }
            
            mutableView.updatePeerIds(transaction: transaction)
            if mutableView.peerIds != previousPeerIds {
                updateType = .UpdateVisible
                
                let _ = mutableView.refreshDueToExternalTransaction(postbox: postbox)
                updated = true
            }
        
            if updated {
                updateTrackedHoles = true
                mutableView.render(self.renderMessage)
                
                pipe.putNext((MessageHistoryView(mutableView), updateType))
            }
        }
        
        for (mutableView, pipe) in self.messageViews.copyItems() {
            let operations = transaction.currentOperationsByPeerId[mutableView.messageId.peerId]
            if operations != nil || !transaction.updatedMedia.isEmpty || !transaction.currentUpdatedCachedPeerData.isEmpty {
                if mutableView.replay(operations ?? [], updatedMedia: transaction.updatedMedia, renderIntermediateMessage: self.renderMessage) {
                    pipe.putNext(MessageView(mutableView))
                }
            }
        }
        
        if !transaction.chatListOperations.isEmpty || !transaction.currentUpdatedPeerNotificationSettings.isEmpty || !transaction.currentUpdatedPeers.isEmpty || !transaction.currentInvalidateMessageTagSummaries.isEmpty || !transaction.currentUpdatedMessageTagSummaries.isEmpty || !transaction.currentOperationsByPeerId.isEmpty || transaction.replacedAdditionalChatListItems != nil {
            for (mutableView, pipe) in self.chatListViews.copyItems() {
                let context = MutableChatListViewReplayContext()
                if mutableView.replay(postbox: postbox, operations: transaction.chatListOperations, updatedPeerNotificationSettings: transaction.currentUpdatedPeerNotificationSettings, updatedPeers: transaction.currentUpdatedPeers, transaction: transaction, context: context) {
                    mutableView.complete(postbox: postbox, context: context)
                    mutableView.render(postbox: postbox, renderMessage: self.renderMessage, getPeer: { id in
                        return self.getPeer(id)
                    }, getPeerNotificationSettings: self.getPeerNotificationSettings)
                    pipe.putNext((ChatListView(mutableView, filter: filter), .Generic))
                }
            }
            
            self.updateTrackedChatListHoles()
        }
        
        if updateTrackedHoles {
            self.updateTrackedHoles()
        }
        
        if self.unsentMessageView.replay(transaction.unsentMessageOperations) {
            self.unsentViewUpdated()
        }
        
        if self.synchronizeReadStatesView.replay(transaction.updatedSynchronizePeerReadStateOperations) {
            self.synchronizeReadStateViewUpdated()
        }
        
        for (view, pipe) in self.unreadMessageCountsViews.copyItems() {
            if view.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(UnreadMessageCountsView(view))
            }
        }
        
        if let replaceContactPeerIds = transaction.replaceContactPeerIds {
            for (mutableView, pipe) in self.contactPeerIdsViews.copyItems() {
                if mutableView.replay(updateRemoteTotalCount: transaction.replaceRemoteContactCount, replace: replaceContactPeerIds) {
                    pipe.putNext(ContactPeerIdsView(mutableView))
                }
            }
        }
        
        for (mutableView, pipe) in self.contactPeersViews.copyItems() {
            if mutableView.replay(replacePeerIds: transaction.replaceContactPeerIds, updatedPeerPresences: transaction.currentUpdatedPeerPresences, getPeer: self.getPeer, getPeerPresence: self.getPeerPresence) {
                pipe.putNext(ContactPeersView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.peerViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(PeerView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.peerMergedOperationLogViews.copyItems() {
            if mutableView.replay(operations: transaction.currentPeerMergedOperationLogOperations, getOperations: self.operationLogGetOperations, getTailIndex: self.operationLogGetTailIndex) {
                pipe.putNext(PeerMergedOperationLogView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.timestampBasedMessageAttributesViews.copyItems() {
            if mutableView.replay(operations: transaction.currentTimestampBasedMessageAttributesOperations, getHead: self.getTimestampBasedMessageAttributesHead) {
                pipe.putNext(TimestampBasedMessageAttributesView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.preferencesViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(PreferencesView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.multiplePeersViews.copyItems() {
            if mutableView.replay(updatedPeers: transaction.currentUpdatedPeers, updatedPeerPresences: transaction.currentUpdatedPeerPresences) {
                pipe.putNext(MultiplePeersView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.itemCollectionsViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(ItemCollectionsView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.combinedViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(mutableView.immutableView())
            }
        }
    }
    
    private func updateTrackedChatListHoles() {
        var firstHoles = Set<ChatListHolesEntry>()
        
        for (view, _) in self.chatListViews.copyItems() {
            if let hole = view.firstHole() {
                firstHoles.insert(ChatListHolesEntry(groupId: view.groupId, hole: hole))
            }
        }
    
        if self.chatListHolesView.update(holes: firstHoles) {
            for pipe in self.chatListHolesViewSubscribers.copyItems() {
                pipe.putNext(ChatListHolesView(self.chatListHolesView))
            }
        }
    }
    
    private func updateTrackedHoles() {
        var firstHolesAndTags = Set<MessageHistoryHolesViewEntry>()
        for (view, _) in self.messageHistoryViews.copyItems() {
            if let (hole, direction) = view.firstHole() {
                
                firstHolesAndTags.insert(MessageHistoryHolesViewEntry(hole: hole, direction: direction, tags: view.tagMask))
            }
        }
        
        if self.messageHistoryHolesView.update(firstHolesAndTags) {
            for subscriber in self.messageHistoryHolesViewSubscribers.copyItems() {
                subscriber.putNext(MessageHistoryHolesView(self.messageHistoryHolesView))
            }
        }
    }
    
    private func unsentViewUpdated() {
        for subscriber in self.unsendMessageIdsViewSubscribers.copyItems() {
            subscriber.putNext(UnsentMessageIdsView(self.unsentMessageView.ids))
        }
    }
    
    private func synchronizeReadStateViewUpdated() {
        for subscriber in self.synchronizePeerReadStatesViewSubscribers.copyItems() {
            subscriber.putNext(SynchronizePeerReadStatesView(self.synchronizeReadStatesView))
        }
    }
    
    func messageHistoryHolesViewSignal() -> Signal<MessageHistoryHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(MessageHistoryHolesView(self.messageHistoryHolesView))
                
                let pipe = ValuePipe<MessageHistoryHolesView>()
                let index = self.messageHistoryHolesViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.messageHistoryHolesViewSubscribers.remove(index)
                    }
                })
            }
            return disposable
        }
    }
    
    func chatListHolesViewSignal() -> Signal<ChatListHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(ChatListHolesView(self.chatListHolesView))
                
                let pipe = ValuePipe<ChatListHolesView>()
                let index = self.chatListHolesViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.chatListHolesViewSubscribers.remove(index)
                    }
                })
            }
            return disposable
        }
    }
    
    func unsentMessageIdsViewSignal() -> Signal<UnsentMessageIdsView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(UnsentMessageIdsView(self.unsentMessageView.ids))
                
                let pipe = ValuePipe<UnsentMessageIdsView>()
                let index = self.unsendMessageIdsViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.unsendMessageIdsViewSubscribers.remove(index)
                    }
                })
            }
            return disposable
        }
    }
    
    func synchronizePeerReadStatesViewSignal() -> Signal<SynchronizePeerReadStatesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(SynchronizePeerReadStatesView(self.synchronizeReadStatesView))
                
                let pipe = ValuePipe<SynchronizePeerReadStatesView>()
                let index = self.synchronizePeerReadStatesViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.synchronizePeerReadStatesViewSubscribers.remove(index)
                    }
                })
            }
            return disposable
        }
    }
}

// MARK: - Filters

extension ViewTracker {

    func updateFilters(with filter: @escaping ([MutableChatListEntry]) -> [MutableChatListEntry]) {
        self.filter = filter
        for (mutableView, pipe) in self.chatListViews.copyItems() {
            pipe.putNext((ChatListView(mutableView, filter: filter), .Generic))
        }
    }

}
