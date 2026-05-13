//
//  Jakin-Sesonal.swift
//  Ryu
//
//  Created by Francesco on 27/07/24.
//

import Alamofire
import Foundation

class JikanServiceSeasonalAnime {
    let session = proxySession.createAlamofireProxySession()
    
    func fetchSeasonalAnime(completion: @escaping ([Anime]?) -> Void) {
        let url = "https://api.jikan.moe/v4/seasons/now"
        
        session.request(url)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let data = json["data"] as? [[String: Any]] {
                            
                            let seasonalAnime: [Anime] = data.compactMap { item in
                                guard let id = item["mal_id"] as? Int,
                                      let title = item["title"] as? String,
                                      let images = item["images"] as? [String: Any],
                                      let jpg = images["jpg"] as? [String: Any],
                                      let imageUrl = jpg["large_image_url"] as? String else {
                                    return nil
                                }
                                
                                return Anime(
                                    id: id,
                                    title: Title(romaji: title, english: title, native: title),
                                    coverImage: CoverImage(large: imageUrl),
                                    episodes: nil,
                                    description: nil,
                                    airingAt: nil
                                )
                            }
                            
                            completion(seasonalAnime)
                        } else {
                            print("Error parsing JSON or missing expected fields")
                            completion(nil)
                        }
                    } catch {
                        print("Error parsing JSON: \(error.localizedDescription)")
                        completion(nil)
                    }
                    
                case .failure(let error):
                    print("Error fetching seasonal anime: \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }
}
