//
//  Sequence+Collect.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 25/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

public extension Sequence {

    func collect<K: Hashable, V>() -> [K: V] where Self.Element == (K, V) {
        return dict { val, _ in val }
    }

    func dict<K: Hashable, V>(_ combine: (V, V) -> V) -> [K: V] where Self.Element == (K, V) {
        return .init(self, uniquingKeysWith: combine)
    }

    func collect() -> [Element] {
        return map { $0 }
    }

}

public extension Sequence where Element: Hashable {

    func collect() -> Set<Element> {
        return .init(self)
    }

}
