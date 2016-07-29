//
//  PreviewTransition.swift
//  FAMFullscreenTransitionDemo
//
//  Created by Kazuya Ueoka on 2016/07/29.
//  Copyright © 2016年 Timers-Inc. All rights reserved.
//

import UIKit

@objc public enum PreviewDirection: Int {
    case Open
    case Close
}

public enum PreviewTransitionType {
    case Linear
    case Spring(delay: NSTimeInterval, damping: CGFloat, velocity: CGFloat, options: UIViewAnimationOptions)
    case Delay(delay: NSTimeInterval, options: UIViewAnimationOptions)

    public func animation(duration: NSTimeInterval, animations: () -> Void, completion: ((finished: Bool) -> Void)? = nil) {
        switch self {
        case .Linear:
            UIView.animateWithDuration(duration, animations: animations, completion: completion)
        case .Spring(let delay, let damping, let velocity, let options):
            UIView.animateWithDuration(duration, delay: delay, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: options, animations: animations, completion: completion)
        case .Delay(let delay, let options):
            UIView.animateWithDuration(duration, delay: delay, options: options, animations: animations, completion: completion)
        }
    }
}

public protocol Previewable {
    var imageView: UIImageView { get }
    var fromRect: CGRect { get set }
    var toRect: CGRect { get set }
    var openDuration: NSTimeInterval { get set }
    var closeDuration: NSTimeInterval { get set }
    var direction: PreviewDirection { get set }
    var transition: PreviewTransitionType { get set }
}

public class PreviewPresentor: NSObject, Previewable {
    public var imageView: UIImageView = {
        let imageView: UIImageView = UIImageView()
        imageView.contentMode = UIViewContentMode.ScaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    public var fromRect: CGRect = CGRect.zero
    public var toRect: CGRect = CGRect.zero
    public var openDuration: NSTimeInterval = 0.33
    public var closeDuration: NSTimeInterval = 0.5
    public var direction: PreviewDirection = PreviewDirection.Open
    public var transition: PreviewTransitionType = PreviewTransitionType.Spring(delay: 0.0, damping: 0.75, velocity: 0.0, options: UIViewAnimationOptions.CurveEaseInOut)
}

extension PreviewPresentor: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        if self.direction == PreviewDirection.Open {
            return self.openDuration
        } else {
            return self.closeDuration
        }
    }

    public func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        guard let fromViewController: UIViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey),
            toViewController: UIViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey),
            containerView: UIView = transitionContext.containerView() else {
                return
        }

        let toView: UIView = toViewController.view
        let fromView: UIView = fromViewController.view

        if self.direction == PreviewDirection.Open {
            containerView.insertSubview(toView, aboveSubview: fromView)
            toView.alpha = 0.0
            containerView.addSubview(self.imageView)

            self.imageView.frame = self.fromRect

            self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
                self.imageView.frame = self.toRect
            }, completion: { (finished) in
                toView.alpha = 1.0
                self.imageView.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
            })
        } else {
            containerView.insertSubview(toView, belowSubview: fromView)
            containerView.addSubview(self.imageView)

            self.imageView.frame = self.toRect

            toView.alpha = 1.0
            fromView.alpha = 0.0
            if !transitionContext.isInteractive() {
                self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
                    self.imageView.frame = self.fromRect
                }, completion: { [unowned self] (finished: Bool) in
                    fromView.alpha = 1.0
                    self.imageView.removeFromSuperview()
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
                })
            } else {
//                self.finishClosure = { [weak self] in
//                    fromView.alpha = 1.0
//                    self?.imageView.removeFromSuperview()
//                    self?.imageView.transform = CGAffineTransformIdentity
//                    transitionContext.completeTransition(true)
//                }
//
//                self.cancelClosure = { [weak self] in
//                    fromView.alpha = 1.0
//                    self?.imageView.removeFromSuperview()
//                    self?.imageView.transform = CGAffineTransformIdentity
//                    transitionContext.completeTransition(false)
//                }
            }
        }
    }
}
