//
//  ManagedFolder.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 16/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import CoreData

//@objc final class ManagedFolder: NSManagedObject {
//
//    @NSManaged var id: NSNumber?
//    @NSManaged var name: NSString?
//
//    @NSManaged var isPinned: NSNumber?
//
//    @NSManaged var lastMessageDate: NSDate?
//
//    @NSManaged var peerIds: NSArray?
//    @NSManaged var numberOfUnreadMessages: NSNumber?
//
////    init(
////        context: NSManagedObjectContext,
////        id: NSNumber,
////        name: String,
////        isPinned: Bool = false,
////        lastMessageDate: Date = .init(),
////        peerIds: [NSNumber] = [],
////        numberOfUnreadMessages: Int = 0
////    ) {
////        super.init(context: context)
////        self.id = id
////        self.name = name
////        self.isPinned = isPinned
////        self.lastMessageDate = lastMessageDate
////        self.peerIds = peerIds
////        self.numberOfUnreadMessages = numberOfUnreadMessages
////    }
//
////    static var propertyListCount: UInt32 = 0
////    static let propertyList = class_copyPropertyList(ManagedFolder.self, &propertyListCount).map {}
//
////    @objc var
//
////    var id: Int {
////        get { return read(property: #function) }
////        set { set(property: #function, to: newValue) }
////    }
//
////    static var properties: [String]
////
////    private func getPropertyList() {
////        var propertyListCount: UInt32 = 0
////        let properies = class_copyPropertyList(ManagedFolder.self, &propertyListCount)
////
////        for i in 0 ..< propertyListCount {
////
////        }
////    }
//
////    private func read<V>(property: String) -> V {
////        return value(forKeyPath: property) as! V
////    }
////
////    private func set<V>(property: String, to value: V) {
////
////    }

extension ManagedFolder {

    convenience init(context: NSManagedObjectContext, plainEntity: Folder) {
        self.init(context: context)

        id = plainEntity.id
        name = plainEntity.name
        peerIds = NSSet(array: plainEntity.peerIds.map {
            ManagedPeerId(context: context, plainEntity: $0)
        })
    }

    func toPlainEntity() -> Folder {
        return Folder(
            id: id,
            name: name! as String,
            peerIds: (peerIds! as Set).compactMap { ($0 as? ManagedPeerId)?.toPlainEntity() }
        )
    }

}


