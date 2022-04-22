//
//  TapViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 30.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit
import PDFKit

class TapViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate, UIGestureRecognizerDelegate {
    
    let pdfView = PDFView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemFill
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .done, target: self, action: #selector(backTapped))
        setUpPDFView()
        setUpConstraints()
        setUpTapGesture()
    }
    
    @objc func doneTapped() {
        if let url = URL(string: "https://forms.gle/ScBopwsKBm5C8Gix7") {
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
    
    
    func setUpTapGesture() {
        let touchArea = CGSize(width: 80, height: self.view.frame.height)

            let leftView = UIView(frame: CGRect(origin: .zero, size: touchArea))
            let rightView = UIView(frame: CGRect(origin: CGPoint(x: self.view.frame.width - touchArea.width, y: 0), size: touchArea))

            leftView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(leftViewTapped)))
            rightView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rightViewTapped)))

            leftView.backgroundColor = .clear
            rightView.backgroundColor = .clear

            self.view.addSubview(leftView)
            self.view.addSubview(rightView)
       }
   
    
    @objc func leftViewTapped() {
        print("Left")
        pdfView.goToPreviousPage(pdfView.canGoBack)
    }

    @objc func rightViewTapped() {
        print("Right")
        pdfView.goToNextPage(pdfView.next)
    }

}



