//
//  SourceMenu.swift
//  Ryu
//
//  Created by Francesco on 05/07/24.
//

import UIKit

class SourceMenu {
    static weak var delegate: SourceSelectionDelegate?
    
    static func showSourceSelector(from viewController: UIViewController, barButtonItem: UIBarButtonItem? = nil, sourceView: UIView? = nil, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            let sources: [(String, MediaSource, String)] = [
                ("AnimePahe", .animepahe, "🇺🇸")
            ]
            
            let alertController = UIAlertController(title: "Select Source", message: "Choose your preferred source.", preferredStyle: .actionSheet)
            
            for (title, source, language) in sources {
                let action = UIAlertAction(title: "\(language) \(title)", style: .default) { _ in
                    UserDefaults.standard.set(source.rawValue, forKey: "selectedMediaSource")
                    delegate?.didSelectNewSource()
                    completion()
                }
                
                if let image = UIImage(named: title) {
                    let resizedImage = image.resized(to: CGSize(width: 35, height: 35))
                    action.setValue(resizedImage.withRenderingMode(.alwaysOriginal), forKey: "image")
                }
                
                alertController.addAction(action)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            
            if let popoverController = alertController.popoverPresentationController {
                if let barButtonItem = barButtonItem {
                    popoverController.barButtonItem = barButtonItem
                } else if let sourceView = sourceView {
                    popoverController.sourceView = sourceView
                    popoverController.sourceRect = sourceView.bounds
                }
            }
            
            viewController.present(alertController, animated: true, completion: nil)
        }
    }
}

protocol SourceSelectionDelegate: AnyObject {
    func didSelectNewSource()
}
