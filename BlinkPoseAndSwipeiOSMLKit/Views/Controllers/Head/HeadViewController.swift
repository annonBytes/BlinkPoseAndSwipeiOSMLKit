//
//  HeadViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 29.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit
import PDFKit

protocol headSwiperDelegate{
    func leftPose()
    func rightPose()
}

class HeadViewController : UIViewController, PDFViewDelegate, PDFDocumentDelegate, headSwiperDelegate {
    
    let pdfView = PDFView()
    
    func leftPose() {
        pdfView.goToPreviousPage(pdfView.canGoBack)
    }

    func rightPose() {
        pdfView.goToNextPage(pdfView.next)
    }
    
    var cameraView : CameraView!
    
    override func loadView() {
        view = UIView()
        configureNavigationBarButtonItem()
        addCameraView()
        setUpPDFView()
        setUpConstraints()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Head Swipe"
        cameraView.beginSession()
    }
    
    
    func addCameraView()
    {
        
        cameraView = CameraView()
        cameraView.headDelegate = self
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(Back))
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTapped))
    }
    
   
    
    @objc func doneTapped(){
        if let url = URL(string: "https://forms.gle/epUPJfC1kvsiQf9Q8") {
            UIApplication.shared.open(url)
        }
    }
    
    @objc func Back(){
        let View = HomeViewController()
          navigationController?.pushViewController(View, animated: true)
    }
}
