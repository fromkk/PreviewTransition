//
//  ViewController.swift
//  FAMFullscreenTransitionDemo
//
//  Created by Kazuya Ueoka on 2016/07/29.
//  Copyright © 2016年 Timers-Inc. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

enum PhotoLibraryRequestResult: Int {
    case Success
    case Failure
}

class ViewController: UIViewController {
    typealias PhotoLibraryRequested = (result: PhotoLibraryRequestResult) -> Void

    private enum Constants {
        static let margin: CGFloat = 1.0
        static let rows: Int = 4
    }

    lazy var collectionViewLayout: UICollectionViewFlowLayout = {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = Constants.margin
        layout.minimumInteritemSpacing = Constants.margin

        let length: CGFloat = (self.view.bounds.size.width - CGFloat(Constants.rows + 1) * Constants.margin) / CGFloat(Constants.rows)
        layout.itemSize = CGSize(width: length, height: length)
        layout.scrollDirection = UICollectionViewScrollDirection.Vertical

        return layout
    }()

    lazy var collectionView: UICollectionView = {
        let collectionView: UICollectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: self.collectionViewLayout)
        collectionView.backgroundColor = UIColor.whiteColor()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.registerClass(ViewControllerCell.self, forCellWithReuseIdentifier: ViewControllerCell.cellIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        return collectionView
    }()

    var fetchResult: PHFetchResult?
    lazy var imageManager: PHCachingImageManager = {
        let imageManager: PHCachingImageManager = PHCachingImageManager()
        return imageManager
    }()

    override func loadView() {
        super.loadView()

        self.view.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(self.collectionView)
        self.view.addConstraints([
            NSLayoutConstraint(item: self.collectionView, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.CenterX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: self.collectionView, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.CenterY, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: self.collectionView, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Width, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: self.collectionView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Height, multiplier: 1.0, constant: 0.0),
            ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.requestPhotoLibrary { [unowned self] (result: PhotoLibraryRequestResult) in
            if result == PhotoLibraryRequestResult.Success {
                dispatch_async(dispatch_get_main_queue(), {
                    guard let collection: PHAssetCollection = PHAssetCollection.fetchAssetCollectionsWithType(PHAssetCollectionType.SmartAlbum, subtype: PHAssetCollectionSubtype.SmartAlbumUserLibrary, options: nil).firstObject as? PHAssetCollection else {
                        return
                    }
                    self.fetchResult = PHAsset.fetchAssetsInAssetCollection(collection, options: nil)
                    self.collectionView.reloadData()
                })
            }
        }
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let length: CGFloat = (self.view.bounds.size.width - CGFloat(Constants.rows + 1) * Constants.margin) / CGFloat(Constants.rows)
        self.collectionViewLayout.itemSize = CGSize(width: length, height: length)
        self.collectionView.performBatchUpdates(nil, completion: nil)
    }

    private func requestPhotoLibrary(result: PhotoLibraryRequested) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .Authorized:
            result(result: PhotoLibraryRequestResult.Success)
            return
        case .NotDetermined:
            PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) in
                switch status {
                case .Authorized:
                    result(result: PhotoLibraryRequestResult.Success)
                    return
                default:
                    result(result: PhotoLibraryRequestResult.Failure)
                    return
                }
            })
        default:
            result(result: PhotoLibraryRequestResult.Failure)
            return
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private var selectedIndexPath: NSIndexPath?
    private var previewTransition: PreviewTransition?
}

extension ViewController: UICollectionViewDataSource {
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.fetchResult?.count ?? 0
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        guard let cell: ViewControllerCell = collectionView.dequeueReusableCellWithReuseIdentifier(ViewControllerCell.cellIdentifier, forIndexPath: indexPath) as? ViewControllerCell else {
            fatalError("viewControllerCell generate failed")
        }
        if let asset: PHAsset = self.fetchResult?.objectAtIndex(indexPath.row) as? PHAsset {
            cell.imageRequestID = self.imageManager.requestImageForAsset(asset, targetSize: cell.frame.size, contentMode: PHImageContentMode.Default, options: nil, resultHandler: { (image: UIImage?, meta: [NSObject : AnyObject]?) in
                guard let imageRequestID: PHImageRequestID = (meta?[PHImageResultRequestIDKey] as? NSNumber)?.intValue else {
                    print("imageRequestID get failed")
                    return
                }

                if let image = image where cell.imageRequestID == imageRequestID {
                    cell.imageView.image = image
                }
            })
        }

        return cell
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        guard let cell: ViewControllerCell = cell as? ViewControllerCell else {
            return
        }

        if let imageRequestID: PHImageRequestID = cell.imageRequestID {
            self.imageManager.cancelImageRequest(imageRequestID)
        }
    }

    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        guard let cell: ViewControllerCell = self.collectionView.cellForItemAtIndexPath(indexPath) as? ViewControllerCell,
        asset: PHAsset = self.fetchResult?.objectAtIndex(indexPath.row) as? PHAsset
        else {
            return
        }

        let fromRect: CGRect = self.collectionView.convertRect(cell.frame, toView: nil)

        self.selectedIndexPath = indexPath

        let previewController: PreviewController = PreviewController()
        self.imageManager.requestImageForAsset(asset, targetSize: UIScreen.mainScreen().bounds.size, contentMode: PHImageContentMode.Default, options: nil) { (image: UIImage?, info: [NSObject : AnyObject]?) in
            previewController.imageView.image = image
        }

        previewController.modalPresentationStyle = UIModalPresentationStyle.Custom

        let toSize: CGSize = cell.imageView.image?.sizeForAspectFit(UIScreen.mainScreen().bounds.size) ?? CGSize.zero

        self.previewTransition = PreviewTransition()
        self.previewTransition?.fromRect = fromRect
        self.previewTransition?.toRect = CGRect(origin: CGPoint(x: (UIScreen.mainScreen().bounds.size.width - toSize.width) / 2.0, y: (UIScreen.mainScreen().bounds.size.height - toSize.height) / 2.0), size: toSize)
        self.previewTransition?.imageView.image = cell.imageView.image

        let navigationController: UINavigationController = UINavigationController(rootViewController: previewController)
        navigationController.transitioningDelegate = self.previewTransition
        self.presentViewController(navigationController, animated: true, completion: nil)
    }
}
