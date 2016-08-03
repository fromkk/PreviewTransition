//
//  PreviewController.swift
//  FAMFullscreenTransitionDemo
//
//  Created by Kazuya Ueoka on 2016/07/29.
//  Copyright © 2016年 Timers-Inc. All rights reserved.
//

import UIKit
import PreviewTransition

class PreviewController: UIViewController {
    lazy var imageView: UIImageView = {
        let imageView: UIImageView = UIImageView()
        imageView.contentMode = UIViewContentMode.ScaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    lazy var closeButton: UIBarButtonItem = {
        UIBarButtonItem(title: "close", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(self.close))
    }()

    override func loadView() {
        super.loadView()

        self.view.backgroundColor = UIColor.whiteColor()
        self.navigationItem.leftBarButtonItem = self.closeButton

        self.view.addSubview(self.imageView)
        self.view.addConstraints([
            NSLayoutConstraint(item: self.imageView, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.CenterX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: self.imageView, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.CenterY, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: self.imageView, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Width, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: self.imageView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Height, multiplier: 1.0, constant: 0.0),
        ])
    }

    func close() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension PreviewController: PreviewTransitionPresented {
    func previewTransitionImage(previewTransition: Previewable) -> UIImage? {
        return self.imageView.image
    }

    func previewTransitionToRect(previewTransition: Previewable) -> CGRect {
        let toSize: CGSize = self.imageView.image?.sizeForAspectFit(UIScreen.mainScreen().bounds.size) ?? CGSize.zero
        return CGRect(origin: CGPoint(x: (UIScreen.mainScreen().bounds.size.width - toSize.width) / 2.0, y: (UIScreen.mainScreen().bounds.size.height - toSize.height) / 2.0), size: toSize)
    }
}
