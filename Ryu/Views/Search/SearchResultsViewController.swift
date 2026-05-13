//
//  SearchResultsViewController.swift
//  Ryu
//
//  Created by Francesco on 21/06/24.
//

import UIKit
import Kingfisher
import Alamofire
import SwiftSoup
import SafariServices

class SearchResultsViewController: UIViewController {
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private lazy var changeSourceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Change Source", for: .normal)
        button.addTarget(self, action: #selector(changeSourceButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let errorLabel = UILabel()
    private let noResultsLabel = UILabel()
    
    var searchResults: [(title: String, imageUrl: String, href: String)] = []
    var filteredResults: [(title: String, imageUrl: String, href: String)] = []
    var query: String = ""
    var selectedSource: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupUI()
        fetchResults()
    }
    
    private func setupUI() {
        navigationItem.largeTitleDisplayMode = .never
        
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .systemBackground
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "resultCell")
        
        setupLoadingIndicator()
        setupErrorLabel()
        setupNoResultsLabel()
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupErrorLabel() {
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupNoResultsLabel() {
        noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        noResultsLabel.textAlignment = .center
        noResultsLabel.text = "No results found"
        noResultsLabel.isHidden = true
        
        view.addSubview(noResultsLabel)
        view.addSubview(changeSourceButton)
        
        NSLayoutConstraint.activate([
            noResultsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noResultsLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            changeSourceButton.topAnchor.constraint(equalTo: noResultsLabel.bottomAnchor, constant: 20),
            changeSourceButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc private func changeSourceButtonTapped() {
        SourceMenu.showSourceSelector(from: self, sourceView: changeSourceButton) { [weak self] in
            self?.refreshResults()
        }
    }
    
    func refreshResults() {
        fetchResults()
    }
    
    private func fetchResults() {
        let session = proxySession.createAlamofireProxySession()
        
        loadingIndicator.startAnimating()
        tableView.isHidden = true
        errorLabel.isHidden = true
        noResultsLabel.isHidden = true
        changeSourceButton.isHidden = true
        
        guard let selectedSource = UserDefaults.standard.selectedMediaSource?.rawValue else {
            loadingIndicator.stopAnimating()
            SourceMenu.showSourceSelector(from: self, sourceView: view) { [weak self] in
                self?.refreshResults()
            }
            return
        }
        
        guard let urlParameters = getUrlAndParameters(for: selectedSource) else {
            showError("Unsupported media source.")
            SourceMenu.showSourceSelector(from: self, sourceView: view) { [weak self] in
                self?.refreshResults()
            }
            return
        }
        
        session.request(urlParameters.url, method: .get, parameters: urlParameters.parameters).responseString { [weak self] response in
            guard let self = self else { return }
            self.loadingIndicator.stopAnimating()
            
            switch response.result {
            case .success(let value):
                let results = self.parseHTML(html: value, for: MediaSource(rawValue: selectedSource) ?? .animepahe)
                self.searchResults = results
                self.filteredResults = results
                if results.isEmpty {
                    self.showNoResults()
                } else {
                    self.tableView.isHidden = false
                    self.tableView.reloadData()
                }
            case .failure(let error):
                self.handleFailure(response: response, error: error)
            }
        }
    }
    
    private func handleFailure(response: DataResponse<String, AFError>, error: AFError) {
        if let httpStatusCode = response.response?.statusCode {
            switch httpStatusCode {
            case 400: self.showError("Bad request. Please check your input and try again.")
            case 403: self.showError("Access forbidden. You don't have permission to access this resource.")
            case 404: self.showError("Resource not found. Please try a different search.")
            case 429: self.showError("Too many requests. Please slow down and try again later.")
            case 500: self.showError("Internal server error. Please try again later.")
            default: self.showError("Unexpected error occurred. Please try again later.")
            }
        } else if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet: self.showError("No internet connection. Please check your network and try again.")
            case NSURLErrorTimedOut: self.showError("Request timed out. Please try again later.")
            default: self.showError("Network error occurred. Please try again later.")
            }
        } else {
            self.showError("Failed to fetch data. Please try again later.")
        }
    }
    
    private func getUrlAndParameters(for source: String) -> (url: String, parameters: Parameters)? {
        switch source {
        case "AnimePahe":
            return ("https://animepahe.pw/api", ["m": "search", "q": query])
        default:
            return nil
        }
    }
    
    private func showError(_ message: String) {
        loadingIndicator.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false
    }
    
    private func showNoResults() {
        noResultsLabel.isHidden = false
        changeSourceButton.isHidden = false
    }
    
    func parseHTML(html: String, for source: MediaSource) -> [(title: String, imageUrl: String, href: String)] {
        switch source {
        case .animepahe:
            return parseAnimePahe(html)
        }
    }
    
    private func navigateToAnimeDetail(title: String, imageUrl: String, href: String) {
        let detailVC = AnimeDetailViewController()
        let selectedMedaiSource = UserDefaults.standard.string(forKey: "selectedMediaSource") ?? "AnimePahe"
        
        detailVC.configure(title: title, imageUrl: imageUrl, href: href, source: selectedMedaiSource)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension SearchResultsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "resultCell", for: indexPath) as! SearchResultCell
        let result = filteredResults[indexPath.row]
        cell.configure(with: result)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedResult = filteredResults[indexPath.row]
        navigateToAnimeDetail(title: selectedResult.title, imageUrl: selectedResult.imageUrl, href: selectedResult.href)
    }
}

extension SearchResultsViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = interaction.view as? UITableViewCell,
              let indexPath = tableView.indexPath(for: cell) else {
                  return nil
              }
        
        let result = searchResults[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            let detailVC = AnimeDetailViewController()
            let selectedMedaiSource = UserDefaults.standard.string(forKey: "selectedMediaSource") ?? "AnimePahe"
            detailVC.configure(title: result.title, imageUrl: result.imageUrl, href: result.href, source: selectedMedaiSource)
            return detailVC
        }, actionProvider: { _ in
            let openAction = UIAction(title: "Open", image: UIImage(systemName: "arrow.up.right.square")) { [weak self] _ in
                self?.navigateToAnimeDetail(title: result.title, imageUrl: result.imageUrl, href: result.href)
            }
            
            let favoriteAction = UIAction(title: self.isFavorite(for: result) ? "Remove from the Library" : "Add to Library", image: UIImage(systemName: self.isFavorite(for: result) ? "bookmark.fill" : "bookmark")) { [weak self] _ in
                self?.toggleFavorite(for: result)
            }
            
            return UIMenu(title: "", children: [openAction, favoriteAction])
        })
    }
    
    private func isFavorite(for result: (title: String, imageUrl: String, href: String)) -> Bool {
        guard let anime = createFavoriteAnime(from: result) else { return false }
        return FavoritesManager.shared.isFavorite(anime)
    }
    
    private func toggleFavorite(for result: (title: String, imageUrl: String, href: String)) {
        guard let anime = createFavoriteAnime(from: result) else { return }
        
        if FavoritesManager.shared.isFavorite(anime) {
            FavoritesManager.shared.removeFavorite(anime)
        } else {
            FavoritesManager.shared.addFavorite(anime)
        }
        
        if let index = searchResults.firstIndex(where: { $0.href == result.href }) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }
    
    private func createFavoriteAnime(from result: (title: String, imageUrl: String, href: String)) -> FavoriteItem? {
        guard let imageURL = URL(string: result.imageUrl),
              let contentURL = URL(string: result.href) else {
                  return nil
              }
        let selectedMediaSource = UserDefaults.standard.string(forKey: "selectedMediaSource") ?? "AnimePahe"
        
        return FavoriteItem(title: result.title, imageURL: imageURL, contentURL: contentURL, source: selectedMediaSource)
    }
}

class SearchResultCell: UITableViewCell {
    let animeImageView = UIImageView()
    let titleLabel = UILabel()
    let disclosureIndicatorImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        configureAppearance()
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.1) {
            self.contentView.alpha = highlighted ? 0.7 : 1.0
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        animeImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        disclosureIndicatorImageView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(animeImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(disclosureIndicatorImageView)
        
        NSLayoutConstraint.activate([
            animeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            animeImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            animeImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            animeImageView.widthAnchor.constraint(equalToConstant: 100),
            
            titleLabel.leadingAnchor.constraint(equalTo: animeImageView.trailingAnchor, constant: 15),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: disclosureIndicatorImageView.leadingAnchor, constant: -10),
            
            disclosureIndicatorImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            disclosureIndicatorImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            disclosureIndicatorImageView.widthAnchor.constraint(equalToConstant: 10),
            disclosureIndicatorImageView.heightAnchor.constraint(equalToConstant: 15)
        ])
        
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(equalToConstant: 160)
        ])
        
        animeImageView.clipsToBounds = true
        animeImageView.contentMode = .scaleAspectFill
        
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        
        disclosureIndicatorImageView.image = UIImage(systemName: "chevron.compact.right")
        disclosureIndicatorImageView.tintColor = .gray
    }
    
    private func configureAppearance() {
        backgroundColor = UIColor.systemBackground
    }
    
    func configure(with result: (title: String, imageUrl: String, href: String)) {
        titleLabel.text = result.title
        if let url = URL(string: result.imageUrl) {
            animeImageView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"), options: [.transition(.fade(0.2)), .cacheOriginalImage])
        }
    }
}
