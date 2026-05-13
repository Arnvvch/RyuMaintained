//
//  AnimeDetailsMethods.swift
//  Ryu
//
//  Created by Francesco on 19/09/24.
//

import UIKit
import SwiftSoup

extension AnimeDetailViewController {
    
    func fetchHTMLContent(from url: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "Invalid data", code: 0, userInfo: nil)))
                return
            }
            
            completion(.success(htmlString))
        }.resume()
    }
    
    func extractAnimePaheVideoURL(from htmlString: String, completion: @escaping (URL?) -> Void) {
        do {
            let doc = try SwiftSoup.parse(htmlString)
            let scripts = try doc.select("script")
            for script in scripts {
                let scriptText = try script.html()
                if scriptText.contains("eval(p,a,c,k,e,d)") {
                    let urlPattern = #"https?://[^\s"'<>]+?\.m3u8"#
                    if let regex = try? NSRegularExpression(pattern: urlPattern, options: []),
                       let match = regex.firstMatch(in: scriptText, range: NSRange(scriptText.startIndex..., in: scriptText)),
                       let range = Range(match.range, in: scriptText) {
                        completion(URL(string: String(scriptText[range])))
                        return
                    }
                }
            }
        } catch {
            print("Error parsing KWIK page: \(error)")
        }
        completion(nil)
    }
    
    func handleAnimePaheSource(htmlString: String, cell: EpisodeCell, fullURL: String) {
        do {
            let doc = try SwiftSoup.parse(htmlString)
            let resolutionLinks = try doc.select("#resolutionMenu .dropdown-item")
            
            var options: [(label: String, kwikUrl: String)] = []
            for link in resolutionLinks {
                let label = try link.text()
                let kwikUrl = try link.attr("data-src")
                options.append((label: label, kwikUrl: kwikUrl))
            }
            
            if options.isEmpty {
                self.hideLoadingBanner {
                    self.showAlert(withTitle: "Error", message: "No resolutions found for this episode.")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.hideLoadingBanner {
                    self.presentResolutionSelection(options: options) { selectedKwikUrl in
                        self.showLoadingBanner()
                        self.fetchHTMLContent(from: selectedKwikUrl) { result in
                            switch result {
                            case .success(let kwikHtml):
                                self.extractAnimePaheVideoURL(from: kwikHtml) { videoURL in
                                    DispatchQueue.main.async {
                                        self.hideLoadingBanner()
                                        if let url = videoURL {
                                            self.playVideo(sourceURL: url, cell: cell, fullURL: fullURL)
                                        } else {
                                            self.showAlert(withTitle: "Error", message: "Failed to extract video URL from KWIK.")
                                        }
                                    }
                                }
                            case .failure(let error):
                                DispatchQueue.main.async {
                                    self.hideLoadingBanner()
                                    self.showAlert(withTitle: "Error", message: "Failed to load KWIK page: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            self.hideLoadingBanner {
                self.showAlert(withTitle: "Error", message: "Error parsing AnimePahe play page.")
            }
        }
    }
    
    private func presentResolutionSelection(options: [(label: String, kwikUrl: String)], completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: "Select Resolution", message: nil, preferredStyle: .actionSheet)
        
        for option in options {
            alert.addAction(UIAlertAction(title: option.label, style: .default) { _ in
                completion(option.kwikUrl)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
}
