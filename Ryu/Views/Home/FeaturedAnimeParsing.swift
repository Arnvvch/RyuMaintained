//
//  FeaturedAnimeParsing.swift
//  Ryu
//
//  Created by Francesco on 01/08/24.
//

import UIKit
import SwiftSoup

extension HomeViewController {
    func getSourceInfo(for source: String) -> (String?, ((Document) throws -> [AnimeItem])?) {
        switch source {
        case "AnimePahe":
            return ("https://animepahe.pw/", parseAnimePaheFeatured)
        default:
            return (nil, nil)
        }
    }
    
    func parseAnimePaheFeatured(_ doc: Document) throws -> [AnimeItem] {
        let animeItems = try doc.select(".episode-list .episode-wrap")
        return try animeItems.array().compactMap { item in
            let titleElement = try item.select(".episode-title a").first()
            let title = try titleElement?.text() ?? ""
            
            let imageElement = try item.select(".episode-snapshot img").first()
            let imageURL = try imageElement?.attr("src") ?? ""
            
            var href = try titleElement?.attr("href") ?? ""
            if href.contains("/play/") {
                href = href.replacingOccurrences(of: "/play/", with: "/anime/")
                if let lastSlashIndex = href.lastIndex(of: "/") {
                    href = String(href[..<lastSlashIndex])
                }
            }
            
            return AnimeItem(title: title, imageURL: imageURL, href: "https://animepahe.pw" + href)
        }
    }
}
