//
//  SwipeViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 18.04.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit
import PDFKit

class SwipeViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate, UIGestureRecognizerDelegate {
    
    let pdfView = PDFView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemFill
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .done, target: self, action: #selector(backTapped))
        setUpPDFView()
        setUpConstraints()
        setUpSwipeGesture()
    }
    
    @objc func doneTapped() {
        if let url = URL(string: "https://forms.gle/wj8MGZLxWhwBQqEB9") {
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
    
    
    func setUpSwipeGesture() {
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(moveToNextItem(_:)))
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(moveToNextItem(_:)))
        leftSwipe.direction = .left
        rightSwipe.direction = .right
        pdfView.addGestureRecognizer(leftSwipe)
        pdfView.addGestureRecognizer(rightSwipe)
       }
   
    
    @objc func moveToNextItem(_ sender:UISwipeGestureRecognizer) {
        switch sender.direction{
        case .left:
            pdfView.goToNextPage(pdfView.next)
        case .right:
            pdfView.goToPreviousPage(pdfView.canGoBack)
        default:
            print("default")
        }
    }


}
