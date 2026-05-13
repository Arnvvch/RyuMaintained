//
//  AnimeDetailService.swift
//  Ryu
//
//  Created by Francesco on 25/06/24.
//

import UIKit
import Alamofire
import SwiftSoup

struct AnimeDetail {
    let aliases: String
    let synopsis: String
    let airdate: String
    let stars: String
    let episodes: [Episode]
}

class AnimeDetailService {
    static let session = proxySession.createAlamofireProxySession()
    
    static func fetchAnimeDetails(from href: String, completion: @escaping (Result<AnimeDetail, Error>) -> Void) {
        guard let _ = UserDefaults.standard.selectedMediaSource else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No media source selected."])))
            return
        }
        
        // AnimePahe details are on the page itself
        session.request(href).responseString { response in
            switch response.result {
            case .success(let html):
                do {
                    let document = try SwiftSoup.parse(html)
                    
                    let aliases = try document.select("header.anime-header h1 span").text()
                    let synopsis = try document.select("div.anime-summary").text()
                    let airdate = try document.select("div.anime-info p:contains(Aired:)").text().replacingOccurrences(of: "Aired: ", with: "")
                    let stars = try document.select("div.anime-info p:contains(Score:)").text().replacingOccurrences(of: "Score: ", with: "")
                    
                    self.fetchAnimePaheEpisodes(document: document, href: href) { result in
                        switch result {
                        case .success(let episodes):
                            let details = AnimeDetail(aliases: aliases, synopsis: synopsis, airdate: airdate, stars: stars, episodes: episodes)
                            completion(.success(details))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private static func fetchAnimePaheEpisodes(document: Document, href: String, completion: @escaping (Result<[Episode], Error>) -> Void) {
        do {
            let html = try document.html()
            let pattern = #"id:\s*['"](\d+)['"]"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
                  let range = Range(match.range(at: 1), in: html) else {
                completion(.failure(NSError(domain: "AnimePahe", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find anime ID"])))
                return
            }
            
            let animeId = String(html[range])
            let apiUrl = "https://animepahe.pw/api?m=release&id=\(animeId)&sort=recent&page=1"
            
            session.request(apiUrl).responseJSON { response in
                switch response.result {
                case .success(let json):
                    guard let dict = json as? [String: Any],
                          let data = dict["data"] as? [[String: Any]] else {
                        completion(.failure(NSError(domain: "AnimePahe", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid episodes data"])))
                        return
                    }
                    
                    let episodes = data.compactMap { item -> Episode? in
                        guard let episodeNumber = item["episode"] as? Int,
                              let session = item["session"] as? String else {
                            return nil
                        }
                        
                        let animeSession = href.components(separatedBy: "/").last ?? ""
                        let episodeHref = "https://animepahe.pw/play/\(animeSession)/\(session)"
                        
                        return Episode(number: "\(episodeNumber)", href: episodeHref, downloadUrl: "")
                    }
                    
                    completion(.success(episodes.sorted { Int($0.number) ?? 0 < Int($1.number) ?? 0 }))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
