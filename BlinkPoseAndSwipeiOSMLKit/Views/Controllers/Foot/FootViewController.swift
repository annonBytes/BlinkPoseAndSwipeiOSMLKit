//
//  FootViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 31.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import UIKit
import PDFKit

class FootViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate, UIGestureRecognizerDelegate {
    
    let pdfView = PDFView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemFill
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTapped))
        setUpPDFView()
        setUpConstraints()
    }
    
    override var canBecomeFirstResponder: Bool {
      true
    }
    
    @objc func doneTapped() {
        if let url = URL(string: "https://forms.gle/AqWDgTu6bnjXGCog8") {
            UIApplication.shared.open(url)
        }
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
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        
        
        guard let path = Bundle.main.url(forResource: "Lavalse_d_Amelie", withExtension: "pdf") else { return }
        if let document = PDFDocument(url: path) {
            pdfView.document = document
            document.delegate = self
        }
    }
  
}

extension FootViewController {
    // 1
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        // 2
        presses.first?.key.flatMap{ onKeyPressed($0) }
    }
    
    // 3
    func onKeyPressed(_ key: UIKey) {
        switch key.keyCode {
        case .keyboardDownArrow:
            print("On Down arrow pressed")
            pdfView.goToNextPage(pdfView.next)
        case .keyboardUpArrow:
            print("On Up arrow pressed")
            pdfView.goToPreviousPage(pdfView.canGoBack)
        default:
            break
        }
    }
}
