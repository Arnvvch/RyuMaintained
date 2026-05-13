//
//  AnimeDetailsViewController.swift
//  Ryu
//
//  Created by Francesco on 22/06/24.
//

import UIKit
import AVKit
import SwiftSoup
import GoogleCast
import SafariServices

class AnimeDetailViewController: UITableViewController, SynopsisCellDelegate {
    
    var animeTitle: String?
    var imageUrl: String?
    var href: String?
    var source: String?
    
    var aliases: String = ""
    var synopsis: String = ""
    var airdate: String = ""
    var stars: String = ""
    var episodes: [Episode] = []
    
    var isSynopsisExpanded: Bool = false
    var currentEpisodeIndex: Int = 0
    var availableQualities: [String] = []
    var hasSentUpdate: Bool = false
    
    func configure(title: String, imageUrl: String, href: String, source: String) {
        self.animeTitle = title
        self.imageUrl = imageUrl
        self.href = href
        self.source = source
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchDetails()
    }
    
    private func setupUI() {
        title = animeTitle
        tableView.register(EpisodeCell.self, forCellReuseIdentifier: "episodeCell")
        tableView.register(SynopsisCell.self, forCellReuseIdentifier: "synopsisCell")
        tableView.register(AnimeHeaderCell.self, forCellReuseIdentifier: "headerCell")
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshDetails), for: .valueChanged)
    }
    
    @objc private func refreshDetails() {
        fetchDetails()
    }
    
    private func fetchDetails() {
        guard let href = href else { return }
        
        AnimeDetailService.fetchAnimeDetails(from: href) { [weak self] result in
            DispatchQueue.main.async {
                self?.refreshControl?.endRefreshing()
                switch result {
                case .success(let details):
                    self?.aliases = details.aliases
                    self?.synopsis = details.synopsis
                    self?.airdate = details.airdate
                    self?.stars = details.stars
                    self?.episodes = details.episodes
                    self?.tableView.reloadData()
                case .failure(let error):
                    self?.showAlert(withTitle: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func showAlert(withTitle title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // Header
        case 1: return 1 // Synopsis
        case 2: return episodes.count // Episodes
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "headerCell", for: indexPath) as! AnimeHeaderCell
            cell.configure(title: animeTitle, imageUrl: imageUrl, aliases: aliases, isFavorite: false, airdate: airdate, stars: stars, href: href)
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "synopsisCell", for: indexPath) as! SynopsisCell
            cell.configure(synopsis: synopsis, isExpanded: isSynopsisExpanded)
            cell.delegate = self
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "episodeCell", for: indexPath) as! EpisodeCell
            let episode = episodes[indexPath.row]
            cell.configure(episode: episode, delegate: self)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2 {
            let episode = episodes[indexPath.row]
            currentEpisodeIndex = indexPath.row
            if let cell = tableView.cellForRow(at: indexPath) as? EpisodeCell {
                episodeSelected(episode: episode, cell: cell)
            }
        }
    }
    
    func episodeSelected(episode: Episode, cell: EpisodeCell) {
        showLoadingBanner()
        handleEpisodeSelection(episode: episode, cell: cell)
    }
    
    private func handleEpisodeSelection(episode: Episode, cell: EpisodeCell) {
        // AnimePahe is the only source
        fetchHTMLContent(from: episode.href) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let html):
                    self?.handleAnimePaheSource(htmlString: html, cell: cell, fullURL: episode.href)
                case .failure(let error):
                    self?.hideLoadingBanner()
                    self?.showAlert(withTitle: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func showLoadingBanner() {
        let alert = UIAlertController(title: nil, message: "Extracting Video", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true)
    }
    
    func hideLoadingBanner(completion: (() -> Void)? = nil) {
        if let alert = presentedViewController as? UIAlertController {
            alert.dismiss(animated: true, completion: completion)
        } else {
            completion?()
        }
    }
    
    func playVideo(sourceURL: URL, cell: EpisodeCell, fullURL: String) {
        let player = AVPlayer(url: sourceURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        present(playerVC, animated: true) {
            player.play()
        }
    }
    
    func downloadMedia(for episode: Episode) {
        // Placeholder for download logic
        showAlert(withTitle: "Download", message: "Download started for episode \(episode.number)")
    }
    
    func cleanTitle(_ title: String) -> String {
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func openInExternalPlayer(player: String, url: URL) {
        // Placeholder for external player integration
    }
    
    var isReverseSorted: Bool = false
    
    func showAlert(title: String, message: String) {
        showAlert(withTitle: title, message: message)
    }
    
    func fetchAnimeID(title: String, completion: @escaping (Int) -> Void) {
        completion(0)
    }

extension AnimeDetailViewController: SynopsisCellDelegate {
    func synopsisCellDidToggleExpansion(_ cell: SynopsisCell) {
        isSynopsisExpanded.toggle()
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }
}
