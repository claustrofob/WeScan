//
//  ScannerViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

/// An enum used to know if the flashlight was toggled successfully.
enum FlashResult {
    case successful
    case notSuccessful
}

/// The `ScannerViewController` offers an interface to give feedback to the user regarding quadrilaterals that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
final class ScannerViewController: UIViewController {
    
    private var captureSessionManager: CaptureSessionManager?
    private let videoPreviewlayer = AVCaptureVideoPreviewLayer()
    
    /// The view that draws the detected rectangles.
    private let quadView = QuadrilateralView()
    
    lazy private var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy private var flashButton: UIButton = {
        let flashImage = UIImage(named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        let button = UIButton()
        button.setImage(flashImage, for: .normal)
        button.clipsToBounds = true
        button.frame.size = CGSize(width: 40, height: 40)
        button.layer.cornerRadius = 20
        button.backgroundColor = .white
        button.tintColor = .black
        button.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        return button
    }()
    
    lazy private var libraryButton: UIButton = {
        let button = UIButton()
        button.clipsToBounds = true
        button.frame.size = CGSize(width: 48, height: 48)
        button.layer.cornerRadius = 3
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 2
        button.backgroundColor = .black
        button.addTarget(self, action: #selector(openLibrary), for: .touchUpInside)
        return button
    }()
    
    lazy private var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        title = NSLocalizedString("wescan.scanning.title", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Scanning", comment: "The title of the ScannerViewController")
        
        setupViews()
        setupNavButtons()
        setupConstraints()
        
        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewlayer)
        captureSessionManager?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CaptureSession.current.isEditing = false
        CaptureSession.current.autoScanEnabled = false
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        videoPreviewlayer.frame = view.layer.bounds
        
        flashButton.center = shutterButton.center
        flashButton.frame.origin.x = view.bounds.maxX - 20 - flashButton.frame.width
        
        libraryButton.center = shutterButton.center
        libraryButton.frame.origin.x = 20
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.torchMode == .on {
            toggleFlash()
        }
    }
    
    // MARK: - Setups
    
    private func setupViews() {
        view.backgroundColor = .white
        
        view.layer.addSublayer(videoPreviewlayer)
        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        view.addSubview(quadView)
        view.addSubview(shutterButton)
        view.addSubview(activityIndicator)
        view.addSubview(flashButton)
        view.addSubview(libraryButton)
        
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: libraryButton.frame.size.width * scale, height: libraryButton.frame.size.height * scale)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.queryLastLibraryPhoto(size: targetSize)
        }
    }
    
    private func setupNavButtons() {
        flashButton.isHidden = !UIImagePickerController.isFlashAvailable(for: .rear)
    }
    
    private func setupConstraints() {
        var quadViewConstraints = [NSLayoutConstraint]()
        var shutterButtonConstraints = [NSLayoutConstraint]()
        var activityIndicatorConstraints = [NSLayoutConstraint]()
        
        quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
            quadView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ]
        
        shutterButtonConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
            shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
        ]
        
        activityIndicatorConstraints = [
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        
        if #available(iOS 11.0, *) {
            let shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        } else {
            let shutterButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        }
        
        NSLayoutConstraint.activate(quadViewConstraints + shutterButtonConstraints + activityIndicatorConstraints)
    }
    
    // MARK: - Actions
    
    @objc private func captureImage(_ sender: UIButton) {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        guard (imageScannerController.imageScannerDelegate?.imageScannerControllerAllowScan(imageScannerController) ?? true) else { return }
        
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }
    
    @objc private func toggleFlash() {
        guard UIImagePickerController.isFlashAvailable(for: .rear) else { return }
        
        if !flashButton.isSelected && toggleTorch(toOn: true) == .successful {
            flashButton.isSelected = true
            flashButton.tintColor = .yellow
        } else {
            flashButton.isSelected = false
            flashButton.tintColor = .black
            
            toggleTorch(toOn: false)
        }
    }
    
    @objc func openLibrary() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        guard (imageScannerController.imageScannerDelegate?.imageScannerControllerAllowScan(imageScannerController) ?? true) else { return }
        
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self

        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @discardableResult func toggleTorch(toOn: Bool) -> FlashResult {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video), device.hasTorch else { return .notSuccessful }
        guard (try? device.lockForConfiguration()) != nil else { return .notSuccessful }
        
        device.torchMode = toOn ? .on : .off
        device.unlockForConfiguration()
        return .successful
    }
    
    func queryLastLibraryPhoto(size: CGSize) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions)
        if let asset = fetchResult.firstObject {
            PHImageManager.default().requestImage(for: asset,
                                         targetSize: size,
                                         contentMode: .aspectFill,
                                         options: nil,
                                         resultHandler: { image, info in
                                            DispatchQueue.main.async {
                                                self.libraryButton.setImage(image, for: .normal)
                                            }
                      
            })
        }
    }
}

extension ScannerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
        picker.dismiss(animated: true) {
            let editVC = EditScanViewController(image: image.realFixOrientation(), quad: nil, imageScanned: false)
            self.navigationController?.pushViewController(editVC, animated: true)
        }
    }
}

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        
        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true
        
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
    }
    
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        shutterButton.isUserInteractionEnabled = false
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        activityIndicator.stopAnimating()
        
        let editVC = EditScanViewController(image: picture.applyingPortraitOrientation(), quad: quad, imageScanned: true)
        navigationController?.pushViewController(editVC, animated: true)
        
        shutterButton.isUserInteractionEnabled = true
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad = quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }
        
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2.0))

        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)

        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)
        
        let transforms = [scaleTransform, rotationTransform, translationTransform]
        
        let transformedQuad = quad.applyTransforms(transforms)
        
        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
    
}
