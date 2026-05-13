//
//  Sources.swift
//  Ryu
//
//  Created by Francesco on 23/06/24.
//

import Foundation

enum MediaSource: String {
    case animepahe = "AnimePahe"
}

extension MediaSource {
    var displayName: String {
        switch self {
        case .animepahe: return "AnimePahe"
        }
    }
}
