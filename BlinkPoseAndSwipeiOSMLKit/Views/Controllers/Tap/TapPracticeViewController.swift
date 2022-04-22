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

class TapPracticeViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate, UIGestureRecognizerDelegate {
    
    let pdfView = PDFView()
    @IBOutlet weak var totalPagesLabel: UILabel!
    @IBOutlet weak var pageInfoContainer: UIView?
    @IBOutlet weak var currentPageLabel: UILabel?

    private var timer: Timer?

    
 
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemFill
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start Test", style: .plain, target: self, action: #selector(startSwipe))
        setUpPDFView()
        setUpConstraints()
        setUpTapGesture()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange), name: Notification.Name.PDFViewPageChanged, object: nil)
    }
    
        @objc func startSwipe(){
          let tapView = TapViewController()
            navigationController?.pushViewController(tapView, animated: true)
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
        pdfView.usePageViewController(true)
        
        guard let path = Bundle.main.url(forResource: "Lavalse_d_Amelie", withExtension: "pdf") else { return }
        if let document = PDFDocument(url: path) {
            pdfView.document = document
            document.delegate = self
            
            pdfView.setCurrentSelection(nil, animate: true)
        }
        
        
        if let totalPages: Int = pdfView.document?.pageCount {
            totalPagesLabel?.text = String(totalPages)
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
    
    @objc func handlePageChange() {

        if let currentPage: PDFPage = pdfView.currentPage, let pageIndex: Int = pdfView.document?.index(for: currentPage) {
            
            UIView.animate(withDuration: 0.5, animations: {
                
                self.pageInfoContainer?.alpha = 1
            }) { (finished) in
                if finished {
                    
                    self.startTimer()
                }
            }
            
            currentPageLabel?.text = String(pageIndex + 1)
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(whenTimerEnds), userInfo: nil, repeats: false)
    }

    @objc func whenTimerEnds() {
        UIView.animate(withDuration: 1) {
            self.pageInfoContainer?.alpha = 0
        }
    }
   
    
    
    @objc func leftViewTapped() {
        print("Left")
        pdfView.goToPreviousPage(pdfView.canGoBack)
        
//        let currentPage = pdfView.document?.index(for: pdfView.currentPage!)
//        print(currentPage)
    }

    @objc func rightViewTapped() {
        print("Right")
        pdfView.goToNextPage(pdfView.next)
        
//        let currentPage = pdfView.document?.index(for: pdfView.currentPage!)
//        print(currentPage)
    }

}

