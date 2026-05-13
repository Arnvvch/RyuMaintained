//
//  SearchResultSourcesParsing.swift
//  Ryu
//
//  Created by Francesco on 13/07/24.
//

import UIKit
import SwiftSoup

extension SearchResultsViewController {
    func parseAnimePahe(_ jsonString: String) -> [(title: String, imageUrl: String, href: String)] {
        guard let jsonData = jsonString.data(using: .utf8) else { return [] }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                  let data = json["data"] as? [[String: Any]] else {
                return []
            }
            
            return data.compactMap { item in
                guard let title = item["title"] as? String,
                      let poster = item["poster"] as? String,
                      let session = item["session"] as? String else {
                    return nil
                }
                
                let href = "https://animepahe.pw/anime/\(session)"
                return (title: title, imageUrl: poster, href: href)
            }
        } catch {
            print("Error parsing AnimePahe JSON: \(error.localizedDescription)")
            return []
        }
    }
}
