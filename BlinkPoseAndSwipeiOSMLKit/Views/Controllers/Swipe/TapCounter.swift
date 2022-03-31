//
//  TapCounter.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Ockiya Beinmonyu Daniel on 31.03.22.
//  Copyright © 2022 bytes. All rights reserved.
//

import Foundation
import UIKit
import Lottie


class TapCounter: UIViewController {
    
    let animationView = AnimationView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        self.navigationItem.setHidesBackButton(true, animated: true)
        setUpAnimation()
    }
    
    func setUpAnimation() {
        animationView.animation = Animation.named("count")
        animationView.frame = view.bounds
        animationView.backgroundColor = .white
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.play(fromProgress: 0, toProgress: 1, loopMode: .playOnce) { [weak self ] finished in
            if finished {
                let newVc = TapViewController()
                self?.navigationController?.pushViewController(newVc, animated: true)
            }
        }
        view.addSubview(animationView)
    }
}
