//
//  HomeViewController.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 30.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit

class HomeViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    private let viewModel: CollectionViewModel = CollectionViewModel()
    
    let selectLabel: UILabel = {
        let label = UILabel()
        label.text = "Please select a modality"
        label.textColor = .systemGray
        label.font = UIFont(name: "SFProDisplay-Regular", size: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var collectionView: UICollectionView = {
      let layout = UICollectionViewFlowLayout()
      layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 5
        layout.itemSize = CGSize(width: (view.frame.size.width/2)-4,
                                 height:(view.frame.size.width/2)-4)
        
      let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
      collectionView.dataSource = self
      collectionView.delegate = self
        collectionView.layer.cornerRadius = 15
        collectionView.backgroundColor = .systemBackground
      collectionView.showsVerticalScrollIndicator = false
      collectionView.translatesAutoresizingMaskIntoConstraints = false
      return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Modalities"
        navigationController?.navigationBar.prefersLargeTitles = true
        setUpViews()
        collectionView.register(CustomCollectionViewCell.self, forCellWithReuseIdentifier: CustomCollectionViewCell.identifier)
    }
    
   
    
    func setUpViews() {
        view.addSubview(selectLabel)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            selectLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            selectLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
        ])
        collectionView.anchorWithConstantsToTop(top: selectLabel.bottomAnchor,
                                                left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, topConstant: 50, leftConstant: 20, bottomConstant: 0, rightConstant: 20)
    }
    
}


extension HomeViewController {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.collectionModel.count
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let selectedCell = viewModel.collectionModel[indexPath.row]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomCollectionViewCell.identifier, for: indexPath) as! CustomCollectionViewCell
        cell.configureData(with: selectedCell)
        if selectedCell.title == "Tap Modality for \npage turning" {
            cell.backgroundColor = UIColor(red: 0.349, green: 0.059, blue: 0.965, alpha: 1)
        } else if selectedCell.title == "Head gesture for \npage turning" {
            cell.backgroundColor = UIColor(red: 0.184, green: 0.722, blue: 1, alpha: 1)
        }
        else if selectedCell.title == "Wink Modality for \npage turning" {
            cell.backgroundColor = UIColor(red: 0.98, green: 0.388, blue: 0.337, alpha: 1)
        }
        else if selectedCell.title == "Foot pedal for \npage turning" {
            cell.backgroundColor =  UIColor(red: 0.204, green: 0.842, blue: 0.875, alpha: 1)
        }
        else if selectedCell.title == "Swipe gesture for \npage turning" {
            cell.backgroundColor = UIColor(red: 0.06, green: 0.857, blue: 0.536, alpha: 1)
        }
        else {
            cell.backgroundColor = UIColor(red: 0.043, green: 0.176, blue: 0.646, alpha: 1)
        }
        cell.layer.cornerRadius = 12
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        return CGSize(width: 170.0, height: 170.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedCell = viewModel.collectionModel[indexPath.row]
        let vc = PracticeViewController()
        let text = selectedCell.title
        let test = text.replacingOccurrences(of: "\n",
                                             with: "")

        if selectedCell.title == "Tap Modality for \npage turning" {
            let tc = TapModality()
            tc.usedColor = UIColor(red: 0.349, green: 0.059, blue: 0.965, alpha: 1)
            tc.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(tc, animated: true)
            tc.messageTitle = selectedCell.message
            tc.detailTitle = test
        }
        
        else if selectedCell.title == "Head gesture for \npage turning" {
            let hc = HeadModality()
            hc.usedColor = UIColor(red: 0.184, green: 0.722, blue: 1, alpha: 1)
            hc.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(hc, animated: true)
            hc.messageTitle = selectedCell.message
            hc.detailTitle = test
        }
        
        else if selectedCell.title == "Wink Modality for \npage turning" {
            let wc = WinkModality()
            wc.usedColor = UIColor(red: 0.98, green: 0.388, blue: 0.337, alpha: 1)
            wc.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(wc, animated: true)
            wc.messageTitle = selectedCell.message
            wc.detailTitle = test
        }
        
        else if selectedCell.title == "Swipe gesture for \npage turning" {
            let wc = SwipeModality()
            wc.usedColor = UIColor(red: 0.06, green: 0.857, blue: 0.536, alpha: 1)
            wc.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(wc, animated: true)
            wc.messageTitle = selectedCell.message
            wc.detailTitle = test
        }
        
        else if selectedCell.title == "Foot pedal for \npage turning" {
            let wc = FootModality()
            wc.usedColor = UIColor(red: 0.204, green: 0.842, blue: 0.875, alpha: 1)
            wc.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(wc, animated: true)
            wc.messageTitle = selectedCell.message
            wc.detailTitle = test
        }
        
        else {
            vc.usedColor = UIColor(red: 0.043, green: 0.176, blue: 0.646, alpha: 1)
            vc.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(vc, animated: true)
            vc.messageTitle = selectedCell.message
            vc.detailTitle = test
        }
      
    }
}


