//
//  Sequence+Collect.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 25/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

extension Sequence {

    func collect() -> [Element] {
        return map { $0 }
    }

}

extension Sequence where Element: Hashable {

    func collect() -> Set<Element> {
        return .init(self)
    }

}
