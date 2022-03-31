//
//  TapPracticeViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 31.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit
import PDFKit

class TapPracticeViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate {
    
    let pdfView = PDFView()
    var cameraView : CameraView!
    
    override func loadView() {
        view = UIView()
        configureNavigationBarButtonItem()
        setUpPDFView()
        setUpConstraints()
        setUpSwipeGesture()
    }
    
    func setUpPDFView() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayDirection = .horizontal
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        
        
        guard let path = Bundle.main.url(forResource: "practice", withExtension: "pdf") else { return }
        if let document = PDFDocument(url: path) {
            pdfView.document = document
            document.delegate = self
        }
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
    
        func configureNavigationBarButtonItem() {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))
    
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start Test", style: .plain, target: self, action: #selector(startSwipe))
        }
    
        @objc func startSwipe(){
          let tapView = TapViewController()
            navigationController?.pushViewController(tapView, animated: true)
        }
    
        @objc func backTapped() {
            let newVC = HomeViewController()
            navigationController?.pushViewController(newVC, animated: true)
        }
    
    
    
}

