//
//  CustomCollectionViewCell.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 29.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit

class CustomCollectionViewCell: UICollectionViewCell {
    static var identifier = "CustomCollectionViewCell"
    
    private let myImage1: UIImageView = {
        let image = UIImageView()
        image.image = UIImage(named: "_Group_ 1")
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        return image
    }()
    
    private let myLabel2: UILabel = {
        let label = UILabel()
        label.text = "Tap Modality for \n turning pages"
        label.numberOfLines = 2
        label.font = UIFont(name: "Helvetica-Bold", size: 16)
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let myLabel3: UILabel = {
        let label = UILabel()
        label.text = "1 hour - Questionaire"
        label.font = UIFont(name: "Helvetica-Light", size: 12)
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    func setUpViews() {
        addSubview(myImage1)
        addSubview(myLabel2)
        addSubview(myLabel3)
        
        NSLayoutConstraint.activate([
            myImage1.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            myImage1.centerXAnchor.constraint(equalTo: centerXAnchor),
            myImage1.heightAnchor.constraint(equalToConstant: 60),
            myLabel2.topAnchor.constraint(equalTo: myImage1.bottomAnchor, constant: 15),
            myLabel2.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            myLabel3.topAnchor.constraint(equalTo: myLabel2.bottomAnchor, constant: 15),
            myLabel3.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureData(with model: CollectionModel) {
        myImage1.image = UIImage(named: model.image)
        myLabel2.text = model.title
        myLabel3.text = model.message
    }
}
