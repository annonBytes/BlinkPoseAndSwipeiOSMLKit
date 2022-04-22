//
//  PracticeViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 18.04.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit
import PDFKit

class PracticeViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate {
    
    
    let pdfView = PDFView()
    let firstView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 15
        view.backgroundColor = UIColor(red: 0.349, green: 0.059, blue: 0.965, alpha: 1)
        view.clipsToBounds = true
        return view
    }()
    
    let firstImageView: UIImageView = {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.clipsToBounds = true
        image.image = UIImage(named: "_Group_ 1")
        return image
    }()
    
    let titleLabel: UILabel = {
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Tap Modality for turning pages"
        title.font = UIFont(name: "Helvetica-Bold", size: 18)
        title.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        return title
    }()
    
    let messageLabel: UILabel = {
        let message = UILabel()
        message.translatesAutoresizingMaskIntoConstraints = false
        message.text = "Tap modality"
        message.font = UIFont(name: "Helvetica-Light", size: 14)
        message.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        return message
    }()
    
    let instructionsLabel: UILabel = {
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Instructions"
        title.font = UIFont(name: "Helvetica-Bold", size: 24)
        title.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        return title
    }()
    
    let messageTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = "Hello"
        textView.isEditable = false
        return textView
    }()
    

    
    var detailTitle: String = ""
    var messageTitle: String = ""
    var usedColor = UIColor(red: 0.349, green: 0.059, blue: 0.965, alpha: 1)
 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemFill
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .done, target: self, action: #selector(backTapped))
        setUpPDFView()
        setUpConstraints()
        titleLabel.text = detailTitle
        messageLabel.text = messageTitle
        firstView.backgroundColor = usedColor
    }
    
    @objc func backTapped() {
        let newVC = HomeViewController()
        navigationController?.pushViewController(newVC, animated: true)
    }
    
    func setUpConstraints() {
        view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
        ])
    }
    
   
    func setUpPDFView() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayDirection = .horizontal
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        
        
        guard let path = Bundle.main.url(forResource: "Lavalse_d_Amelie", withExtension: "pdf") else { return }
        if let document = PDFDocument(url: path) {
            pdfView.document = document
            document.delegate = self
        }
    }
    
    
}
