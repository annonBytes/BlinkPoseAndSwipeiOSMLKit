//
//  WinkItViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 12.05.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import ARKit
import AVFoundation
import UIKit
import PDFKit

class WinkItViewController: UIViewController, ARSCNViewDelegate, PDFViewDelegate, PDFDocumentDelegate {
    let pdfView = PDFView()
    
    enum EyeState {
        case opened
        case closed
    }
    
    lazy var sceneView: ARSCNView = {
            let sceneView = ARSCNView()
            sceneView.delegate = self
            return sceneView
        }()
    
    private let blinkTimeThreshold: TimeInterval = 0.1
    private let eyeCoefficientThreshold: Float = 0.80
    
    private var leftEyeClosedInterval = DateInterval()
    private var leftEyeState: EyeState = .opened {
        didSet {
            guard oldValue != leftEyeState else {
                return
            }
            switch leftEyeState {
            case .closed:
                leftEyeClosedInterval.start = Date()
            case .opened:
                leftEyeClosedInterval.end = Date()
                leftEyeClosureDidEnd()
            }
        }
    }
    
    private var rightEyeClosedInterval = DateInterval()
    private var rightEyeState: EyeState = .opened {
        didSet {
            guard oldValue != rightEyeState else {
                return
            }
            switch rightEyeState {
            case .closed:
                rightEyeClosedInterval.start = Date()
            case .opened:
                rightEyeClosedInterval.end = Date()
                rightEyeClosureDidEnd()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBarButtonItem()
        // Setup pdfView
        setUpPDFView()
        setUpConstraints()
        // Setup sceneView
        self.view.addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            sceneView.session.run(configuration)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if ARFaceTrackingConfiguration.isSupported {
            sceneView.session.pause()
        }
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
    
    // MARK: - ARSCNViewDelegate Methods
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = sceneView.device else {
            return nil
        }
        
        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
        node.geometry?.firstMaterial?.transparency = 0.0
        
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
            return
        }
        
        faceGeometry.update(from: faceAnchor.geometry)
        
        let leftEyeCoefficient = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0.0
        let rightEyeCoefficient = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0.0
        
        DispatchQueue.main.async {
            self.handleEyeClosureCoefficient(leftEyeCoefficient: leftEyeCoefficient, rightEyeCoefficient: rightEyeCoefficient)
        }
    }
    
    // MARK: - AR Handler Methods
    
    private func handleEyeClosureCoefficient(leftEyeCoefficient: Float, rightEyeCoefficient: Float) {
        // Prevent both eye closures
        if leftEyeCoefficient >= eyeCoefficientThreshold && rightEyeCoefficient >= eyeCoefficientThreshold {
            print("Cancelling, both eyes closed")
            return
        }
        
        //print("leftEyeCoefficient: \(leftEyeCoefficient)  |  rightEyeCoefficient: \(rightEyeCoefficient)")
        leftEyeState = leftEyeCoefficient >= eyeCoefficientThreshold ? .closed : .opened
        rightEyeState = rightEyeCoefficient >= eyeCoefficientThreshold ? .closed : .opened
    }
    
    private func leftEyeClosureDidEnd() {
        print("leftEyeClosureDidEnd | \(leftEyeClosedInterval.duration)")
        if leftEyeClosedInterval.duration >= blinkTimeThreshold {
            pdfView.goToNextPage(pdfView.next)
//            pdfView.goToPreviousPage(pdfView.canGoBack)
        }
    }
    
    private func rightEyeClosureDidEnd() {
        print("rightEyeClosureDidEnd | \(rightEyeClosedInterval.duration)")
        if rightEyeClosedInterval.duration >= blinkTimeThreshold {
            pdfView.goToPreviousPage(pdfView.canGoBack)
//            pdfView.goToNextPage(pdfView.next)
        }
    }
    
    func configureNavigationBarButtonItem() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backTapped))

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTapped))
    }

    @objc func backTapped() {
        let newVC = HomeViewController()
        navigationController?.pushViewController(newVC, animated: true)
    }

    @objc func doneTapped(){
        if let url = URL(string: "https://forms.gle/WBGgYq4M2hpt39of7") {
            UIApplication.shared.open(url)
        }
    }
}
