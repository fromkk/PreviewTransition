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
    var openDuration: NSTimeInterval { get set }
    var closeDuration: NSTimeInterval { get set }
    var transition: PreviewTransitionType { get set }
    var delegate: PreviewTransitionDelegate? { get set }
}

@objc public protocol PreviewTransitionPresenter: class {
    func previewTransitionFromRect(previewTransition: PreviewTransition) -> CGRect
    func previewTransitionImage(previewTransition: PreviewTransition) -> UIImage?
}

@objc public protocol PreviewTransitionPresented: class {
    func previewTransitionToRect(previewTransition: PreviewTransition) -> CGRect
    func previewTransitionImage(previewTransition: PreviewTransition) -> UIImage?
}

@objc public protocol PreviewTransitionDelegate {
    func previewTransitionWillShow(previewTransition: PreviewTransition) -> Void
    func previewTransitionDidShow(previewTransition: PreviewTransition) -> Void
    func previewTransitionWillHide(previewTransition: PreviewTransition) -> Void
    func previewTransitionDidHide(previewTransition: PreviewTransition) -> Void
    func previewTransitionWillCancel(previewTransition: PreviewTransition) -> Void
    func previewTransitionDidCancel(previewTransition: PreviewTransition) -> Void
}

extension PreviewTransitionDelegate {
    func previewTransitionWillShow(previewTransition: PreviewTransition) {}
    func previewTransitionDidShow(previewTransition: PreviewTransition) {}
    func previewTransitionWillHide(previewTransition: PreviewTransition) {}
    func previewTransitionDidHide(previewTransition: PreviewTransition) {}
    func previewTransitionWillCancel(previewTransition: PreviewTransition) {}
    func previewTransitionDidCancel(previewTransition: PreviewTransition) {}
}

extension UIViewControllerContextTransitioning {
    func previewViewController<T>(forKey key: String) -> T? {
        if let navigationController: UINavigationController = self.viewControllerForKey(key) as? UINavigationController, presenterViewController: T = navigationController.topViewController as? T {
            return presenterViewController
        } else if let presenterViewController: T = self.viewControllerForKey(key) as? T {
            return presenterViewController
        }
        return nil
    }
}

public class PreviewTransition: NSObject, Previewable {
    enum PreviewDirection: Int {
        case Open
        case Close
    }

    private lazy var imageView: UIImageView = {
        let imageView: UIImageView = UIImageView()
        imageView.contentMode = UIViewContentMode.ScaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    public var openDuration: NSTimeInterval = 0.33
    public var closeDuration: NSTimeInterval = 0.5
    public var transition: PreviewTransitionType = PreviewTransitionType.Spring(delay: 0.0, damping: 0.75, velocity: 0.0, options: UIViewAnimationOptions.CurveEaseInOut)
    public var delegate: PreviewTransitionDelegate?
    private var direction: PreviewDirection = PreviewDirection.Open
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

extension PreviewTransition: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        if self.direction == PreviewDirection.Open {
            return self.openDuration
        } else {
            return self.closeDuration
        }
    }

    public func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext

        guard let containerView: UIView = transitionContext.containerView() else {
            transitionContext.completeTransition(false)
            return
        }

        if self.direction == PreviewDirection.Open {
            guard let fromViewController: UIViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey),
                toViewController: UIViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey),
                presenterViewController: PreviewTransitionPresenter = transitionContext.previewViewController(forKey: UITransitionContextFromViewControllerKey),
                presentedViewController: PreviewTransitionPresented = transitionContext.previewViewController(forKey: UITransitionContextToViewControllerKey) else {
                transitionContext.completeTransition(false)
                return
            }

            let toView: UIView = toViewController.view
            let fromView: UIView = fromViewController.view

            self.delegate?.previewTransitionWillShow(self)

            containerView.insertSubview(toView, aboveSubview: fromView)
            toView.alpha = 0.0
            containerView.addSubview(self.imageView)

            self.imageView.image = presenterViewController.previewTransitionImage(self)
            self.imageView.frame = presenterViewController.previewTransitionFromRect(self)

            self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
                self.imageView.frame = presentedViewController.previewTransitionToRect(self)
            }, completion: { [unowned self] (finished) in
                toView.alpha = 1.0
                self.imageView.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
                self.delegate?.previewTransitionDidShow(self)
            })
        } else {
            guard let fromViewController: UIViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey),
                toViewController: UIViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey),
            presenterViewController: PreviewTransitionPresenter = transitionContext.previewViewController(forKey: UITransitionContextToViewControllerKey),
            presentedViewController: PreviewTransitionPresented = transitionContext.previewViewController(forKey: UITransitionContextFromViewControllerKey) else {
                transitionContext.completeTransition(false)
                return
            }

            let toView: UIView = toViewController.view
            let fromView: UIView = fromViewController.view

            containerView.addSubview(self.imageView)

            self.imageView.image = presentedViewController.previewTransitionImage(self)
            self.imageView.frame = presentedViewController.previewTransitionToRect(self)

            toView.alpha = 1.0
            fromView.alpha = 0.0
            if !transitionContext.isInteractive() {
                self.delegate?.previewTransitionWillHide(self)
                self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
                    self.imageView.frame = presenterViewController.previewTransitionFromRect(self)
                }, completion: { [unowned self] (finished: Bool) in
                    fromView.alpha = 1.0
                    self.imageView.removeFromSuperview()
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
                    self.delegate?.previewTransitionDidHide(self)
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
        } else if transitionCompleted {
            guard let fromView: UIView = self.transitionContext?.viewForKey(UITransitionContextFromViewKey), panGesture = self.panGesture else {
                return
            }

            fromView.removeGestureRecognizer(panGesture)
        } else {
            self.imageView.transform = CGAffineTransformIdentity
        }
    }
}

extension PreviewTransition {
    private enum Constatns {
        static let closeRate: CGFloat = 0.5
    }
    func panGestureHandler(panGesture: UIPanGestureRecognizer) {
        if panGesture == self.panGesture {
            let translation: CGPoint = panGesture.translationInView(panGesture.view)
            let height: CGFloat = (panGesture.view?.frame.size.height ?? UIScreen.mainScreen().bounds.size.height) * 0.5
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

extension PreviewTransition: UIViewControllerTransitioningDelegate {
    private func previewViewController<T>(fromViewController viewController: UIViewController?) -> T? {
        if let navigationController: UINavigationController = viewController as? UINavigationController {
            if let resultViewController: T = navigationController.topViewController as? T {
                return resultViewController
            }
        } else if let resultViewController: T = viewController as? T {
            return resultViewController
        }
        return nil
    }

    public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {

        guard let _: PreviewTransitionPresenter = self.previewViewController(fromViewController: presenting),
            _: PreviewTransitionPresented = self.previewViewController(fromViewController: presented) else {
            return nil
        }

        self.direction = PreviewDirection.Open
        return self
    }

    public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let _: PreviewTransitionPresented = self.previewViewController(fromViewController: dismissed),
            _: PreviewTransitionPresenter = self.previewViewController(fromViewController: dismissed.presentingViewController) else {
            return nil
        }

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

extension PreviewTransition: PreviewInteractiveTransition {
    func updateInteractiveTransition(percentComplete: CGFloat) {
        self.interactionTransition.updateInteractiveTransition(percentComplete)
    }

    func finishInteractiveTransition() {
        self.interactionTransition.finishInteractiveTransition()

        guard let transitionContext = self.transitionContext,
            presenterViewController: PreviewTransitionPresenter = transitionContext.previewViewController(forKey: UITransitionContextToViewControllerKey) else {
            return
        }

        self.delegate?.previewTransitionWillHide(self)
        self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
            self.imageView.frame = presenterViewController.previewTransitionFromRect(self)
        }) { [unowned self] (finished) in
            self.finishClosure()
            self.delegate?.previewTransitionDidHide(self)
        }
    }

    func cancelInteractiveTransition() {
        self.interactionTransition.cancelInteractiveTransition()

        guard let transitionContext = self.transitionContext,
            toViewController: PreviewTransitionPresented = transitionContext.previewViewController(forKey: UITransitionContextFromViewControllerKey) else {
            return
        }

        self.delegate?.previewTransitionWillCancel(self)
        self.transition.animation(self.transitionDuration(transitionContext), animations: { [unowned self] in
            self.imageView.frame = toViewController.previewTransitionToRect(self)
        }) { [unowned self] (finished) in
            self.cancelClosure()
            self.delegate?.previewTransitionDidCancel(self)
        }
    }
}
