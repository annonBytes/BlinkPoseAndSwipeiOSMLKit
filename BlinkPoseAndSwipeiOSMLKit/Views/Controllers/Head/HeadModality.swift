//
//  HeadModality.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 31.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit

class HeadModality: UIViewController {
    let secondView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 15
        view.backgroundColor = UIColor(red: 0.98, green: 0.388, blue: 0.337, alpha: 1)
        view.clipsToBounds = true
        return view
    }()
    
    let SecondImageView: UIImageView = {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.clipsToBounds = true
        image.image = UIImage(named: "_Group_ 1")
        return image
    }()
    
    let titleLabel: UILabel = {
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Head gesture for page turning"
        title.font = UIFont(name: "Helvetica-Bold", size: 18)
        title.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        return title
    }()
    
    let messageLabel: UILabel = {
        let message = UILabel()
        message.translatesAutoresizingMaskIntoConstraints = false
        message.text = "Head modality"
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
    
    lazy var practiceButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("PRACTICE NOW", for: .normal)
        button.setTitleColor(UIColor(red: 0.184, green: 0.722, blue: 1, alpha: 1), for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 0.184, green: 0.722, blue: 1, alpha: 1).cgColor
        button.addTarget(self, action: #selector(practiceTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var testButton: UIButton = {
         let button = UIButton()
         button.translatesAutoresizingMaskIntoConstraints = false
         button.setTitle("TAKE TEST", for: .normal)
         button.backgroundColor = UIColor(red: 0.184, green: 0.722, blue: 1, alpha: 1)
         button.layer.cornerRadius = 12
         button.addTarget(self, action: #selector(testTapped), for: .touchUpInside)
         return button
     }()
    
    var detailTitle: String = ""
    var messageTitle: String = ""
    var usedColor = UIColor(red: 0.98, green: 0.388, blue: 0.337, alpha: 1)
    override func viewDidLoad() {
        super.viewDidLoad()
       view.backgroundColor = .systemBackground
        self.navigationController?.navigationBar.tintColor = UIColor.systemGray6
        titleLabel.text = detailTitle
        messageLabel.text = messageTitle
        secondView.backgroundColor = usedColor
        setUpConstraint()
        setupView()
    }
    
    func setupView() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.15
        messageTextView.attributedText = NSMutableAttributedString(
            string:
                "You will have to perform a page turn while playing the piano by turning youur head left and right. Right below you can see a button that let’s you see a sample PDF document to practice with. \n\nYou wcan practice the modality with the PDF before proceeding to take the actual test. Once you are satisifed with the practice then you proceed to start the test by clicking on the ‘TAKE TEST’ button. \n\nAlso worth noting that while playing, Try to continue playing admist making mistakes\n\nAfter finishing with note, You will take a short survey to give feedback.",
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.font: UIFont.systemFont(
                    ofSize: 14,
                    weight: .regular),
            ])
    }
    
    func setUpConstraint() {
        view.addSubview(secondView)
        secondView.addSubview(SecondImageView)
        secondView.addSubview(titleLabel)
        secondView.addSubview(messageLabel)
        view.addSubview(instructionsLabel)
        view.addSubview(messageTextView)
        view.addSubview(practiceButton)
        view.addSubview(testButton)
        NSLayoutConstraint.activate([
            secondView.heightAnchor.constraint(equalToConstant: 250),
            secondView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            secondView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            secondView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            SecondImageView.centerXAnchor.constraint(equalTo: secondView.centerXAnchor),
            SecondImageView.topAnchor.constraint(equalTo: secondView.topAnchor, constant: 60),
            SecondImageView.heightAnchor.constraint(equalToConstant: 100),
            SecondImageView.widthAnchor.constraint(equalToConstant: 100),
            titleLabel.topAnchor.constraint(equalTo: SecondImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: secondView.leadingAnchor, constant: 10),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: secondView.leadingAnchor, constant: 10),
            instructionsLabel.topAnchor.constraint(equalTo: secondView.bottomAnchor, constant: 30),
            instructionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            messageTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            messageTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            messageTextView.heightAnchor.constraint(equalToConstant: 300),
            messageTextView.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 10),
            practiceButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            practiceButton.topAnchor.constraint(equalTo: messageTextView.bottomAnchor, constant: 20),
            practiceButton.heightAnchor.constraint(equalToConstant: 50),
            practiceButton.widthAnchor.constraint(equalToConstant: 340),
            testButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            testButton.topAnchor.constraint(equalTo: practiceButton.bottomAnchor, constant: 20),
            testButton.heightAnchor.constraint(equalToConstant: 50),
            testButton.widthAnchor.constraint(equalToConstant: 340),
        ])
    }
    
    @objc func testTapped() {
        let newVc = HeadCounter()
        navigationController?.pushViewController(newVc, animated: true)
    }
    
    @objc func practiceTapped() {
        let newVc = HeadPracticeViewController()
        navigationController?.pushViewController(newVc, animated: true)
    }
}
