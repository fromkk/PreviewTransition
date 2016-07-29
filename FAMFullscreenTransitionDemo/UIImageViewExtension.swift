//
//  UIImageViewExtension.swift
//  FAMFullscreenTransitionDemo
//
//  Created by Kazuya Ueoka on 2016/07/29.
//  Copyright © 2016年 Timers-Inc. All rights reserved.
//

import UIKit

extension UIImage {
    func sizeForAspectFill(viewSize: CGSize) -> CGSize {
        let size = self.size
        let screenSize = viewSize

        let imageAspect: CGFloat = size.height / size.width
        let screenAspect: CGFloat = screenSize.height / screenSize.width

        if imageAspect < screenAspect {
            // 横長の画像
            let ratio: CGFloat = size.height / screenSize.height
            return CGSize(width: size.width / ratio, height: screenSize.height)
        } else {
            // 縦長の画像
            let ratio: CGFloat = size.width / screenSize.width
            return CGSize(width: screenSize.width, height: size.height / ratio)
        }
    }

    func sizeForAspectFit(viewSize: CGSize) -> CGSize {
        let size = self.size
        let screenSize = viewSize

        let imageAspect: CGFloat = size.height / size.width
        let screenAspect: CGFloat = screenSize.height / screenSize.width

        if imageAspect < screenAspect {
            // 横長の画像
            let ratio: CGFloat = size.width / screenSize.width
            return CGSize(width: screenSize.width, height: size.height / ratio)
        } else {
            // 縦長の画像
            let ratio: CGFloat = size.height / screenSize.height
            return CGSize(width: size.width / ratio, height: screenSize.height)
        }
    }
}
