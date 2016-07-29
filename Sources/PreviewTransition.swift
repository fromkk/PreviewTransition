//
//  PreviewTransition.swift
//  FAMFullscreenTransitionDemo
//
//  Created by Kazuya Ueoka on 2016/07/29.
//  Copyright © 2016年 Timers-Inc. All rights reserved.
//

import UIKit

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
    var transition: PreviewTransitionType { get set }
}

public class PreviewPresentor: NSObject, Previewable {
    enum PreviewDirection: Int {
        case Open
        case Close
    }

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
    public var transition: PreviewTransitionType = PreviewTransitionType.Spring(delay: 0.0, damping: 0.75, velocity: 0.0, options: UIViewAnimationOptions.CurveEaseInOut)
    var direction: PreviewDirection = PreviewDirection.Open
    private weak var transitionContext: UIViewControllerContextTransitioning?
    private weak var panGesture: UIPanGestureRecognizer?
    private var panGestureStartPoint: CGPoint?
    private weak var visibleViewController: UIViewController?

    private var isInteractive: Bool = false
    private lazy var interactionTransition: UIPercentDrivenInteractiveTransition = {
        UIPercentDrivenInteractiveTransition()
    }()

    private var finishClosure: () -> Void = {}
    private var cancelClosure: () -> Void = {}
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
        self.transitionContext = transitionContext
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
                self.finishClosure = { [unowned self] in
                    fromView.alpha = 1.0
                    self.imageView.removeFromSuperview()
                    transitionContext.completeTransition(true)
                }
                self.cancelClosure = { [unowned self] in
                    fromView.alpha = 1.0
                    self.imageView.removeFromSuperview()
                    transitionContext.completeTransition(false)
                }
            }
        }
    }

    public func animationEnded(transitionCompleted: Bool) {
        if self.direction == PreviewDirection.Open {
            self.visibleViewController = self.transitionContext?.viewControllerForKey(UITransitionContextToViewControllerKey)
            guard let toView: UIView = self.transitionContext?.viewForKey(UITransitionContextToViewKey) else {
                return
            }

            toView.userInteractionEnabled = true
            let panGesture: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGestureHandler(_:)))
            toView.addGestureRecognizer(panGesture)
            self.panGesture = panGesture
        } else {
            guard let fromView: UIView = self.transitionContext?.viewForKey(UITransitionContextFromViewKey), panGesture = self.panGesture else {
                return
            }

            fromView.removeGestureRecognizer(panGesture)
        }
    }
}

extension PreviewPresentor {
    private enum Constatns {
        static let closeRate: CGFloat = 0.3
    }
    func panGestureHandler(panGesture: UIPanGestureRecognizer) {
        if panGesture == self.panGesture {
            let translation: CGPoint = panGesture.translationInView(panGesture.view)
            let height: CGFloat = (panGesture.view?.frame.size.height ?? UIScreen.mainScreen().bounds.size.height) / 1.5
            let percent: CGFloat = fabs(translation.y / height)
            switch panGesture.state {
            case UIGestureRecognizerState.Began:
                self.panGestureStartPoint = panGesture.locationInView(panGesture.view)
                self.isInteractive = true
                self.visibleViewController?.dismissViewControllerAnimated(true, completion: nil)
            case UIGestureRecognizerState.Changed:
                self.updateInteractiveTransition(percent)
                self.imageView.transform = CGAffineTransformMakeTranslation(translation.x, translation.y)
            default:
                if Constatns.closeRate <= percent {
                    self.finishInteractiveTransition()
                } else {
                    self.cancelInteractiveTransition()
                }
                self.isInteractive = false
                break
            }
        }
    }
}

extension PreviewPresentor: UIViewControllerTransitioningDelegate {
    public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.direction = PreviewDirection.Open
        return self
    }

    public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.direction = PreviewDirection.Close
        return self
    }

    public func interactionControllerForPresentation(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return nil
    }

    public func interactionControllerForDismissal(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if self.isInteractive {
            return self.interactionTransition
        }
        return nil
    }
}

protocol PreviewInteractiveTransition {
    func updateInteractiveTransition(percentComplete: CGFloat) -> Void
    func finishInteractiveTransition() -> Void
    func cancelInteractiveTransition() -> Void
}

extension PreviewPresentor: PreviewInteractiveTransition {
    func updateInteractiveTransition(percentComplete: CGFloat) {
        self.interactionTransition.updateInteractiveTransition(percentComplete)
    }

    func finishInteractiveTransition() {
        self.interactionTransition.finishInteractiveTransition()

        guard let transitionContext = self.transitionContext else {
            return
        }

        self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
            self.imageView.frame = self.fromRect
        }) { (finished) in
            self.finishClosure()
        }
    }

    func cancelInteractiveTransition() {
        self.interactionTransition.cancelInteractiveTransition()

        guard let transitionContext = self.transitionContext else {
            return
        }

        self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
            self.imageView.frame = self.toRect
        }) { (finished) in
            self.cancelClosure()
        }
    }
}
