//
//  WinkPracticeViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 31.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit
import PDFKit

class WinkPracticeViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate, BlinkSwiperDelegate {
    
    let pdfView = PDFView()
    var cameraView : CameraView!
    
    func leftBlink() {
          pdfView.goToPreviousPage(pdfView.canGoBack)
      }
  
      func rightBlink() {
          pdfView.goToNextPage(pdfView.next)
      }
    
    override func loadView() {
        view = UIView()
        configureNavigationBarButtonItem()
        addCameraView()
        setUpPDFView()
        setUpConstraints()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Practice mode"
        cameraView.beginSession()
    }
    
    func addCameraView()
        {
            cameraView = CameraView()
            cameraView.blinkDelegate = self
            view.addSubview(cameraView)
    
            cameraView.translatesAutoresizingMaskIntoConstraints = false
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            cameraView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            cameraView.widthAnchor.constraint(equalToConstant: 150).isActive = true
            cameraView.heightAnchor.constraint(equalToConstant: 150).isActive = true
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
    
    func setUpConstraints() {
        view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
        ])
    }

    func configureNavigationBarButtonItem() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start Test", style: .plain, target: self, action: #selector(startTest))
    }

    @objc func backTapped() {
        let newVC = HomeViewController()
        navigationController?.pushViewController(newVC, animated: true)
    }

    @objc func startTest(){
        let winkView = WinkViewController()
          navigationController?.pushViewController(winkView, animated: true)
    }

}
