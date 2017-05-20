//
//  Errors.swift
//  Face-To-Name
//
//  Created by John Bales on 5/17/17.
//  Copyright © 2017 John T Bales. All rights reserved.
//

import Foundation

enum AlertError: Error {
    case basic(title: String?, message: String?)
}

//Non throwing option for propagating alert messages in asynchronous functions
struct AlertParams {
    var title: String?
    var message: String?
    
    func toString() -> String {
        return "Title: \(title ?? "None"). Message: \(message ?? "None")"
    }
}

