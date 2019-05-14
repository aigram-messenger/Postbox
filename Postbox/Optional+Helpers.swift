//
//  Optional+NonNilAssertion.swift
//  Postbox
//
//  Created by Valeriy Mikholapov on 25/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

extension Optional {

    func or(_ other: Wrapped) -> Wrapped {
        return self ?? other
    }

    func assertNonNil(_ message: String = "Non-nil assertion failed.") -> Wrapped? {
        assert(self != nil, message)
        return self
    }

}
