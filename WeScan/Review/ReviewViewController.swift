//
//  ReviewViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/25/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit

/// The `ReviewViewController` offers an interface to review the image after it has been cropped and deskwed according to the passed in quadrilateral.
final class ReviewViewController: UIViewController {
    
    var enhancedImageIsAvailable = false
    var isCurrentlyDisplayingEnhancedImage = false
    
    lazy private var imageView: MarkupImageView = {
        let imageView = MarkupImageView(frame: CGRect.zero)
        imageView.image = results.scannedImage
        imageView.delegate = self
        return imageView
    }()
    
    lazy private var enhanceButton: UIBarButtonItem = {
        let image = UIImage(named: "enhance", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleEnhancedImage))
        button.tintColor = .black
        return button
    }()
    
    lazy private var undoButton: UIBarButtonItem = {
        let image = UIImage(named: "undo-icon", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(tapUndoImage))
        button.tintColor = .black
        button.isEnabled = false
        return button
    }()
    
    lazy private var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(finishScan))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()
    
    private let results: ImageScannerResults
    
    // MARK: - Life Cycle
    
    init(results: ImageScannerResults) {
        self.results = results
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        enhancedImageIsAvailable = results.enhancedImage != nil
        
        view.backgroundColor = .black
        
        setupViews()
        setupToolbar()
        
        title = NSLocalizedString("wescan.review.title", tableName: nil, bundle: Bundle(for: ReviewViewController.self), value: "Review", comment: "The review title of the ReviewController")
        navigationItem.rightBarButtonItem = doneButton
    }
    
    func addUndoObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.didUndoChange), name: NSNotification.Name.NSUndoManagerDidUndoChange, object: nil)
    }
    
    @objc func didUndoChange() {
        undoButton.isEnabled = undoManager?.canUndo ?? false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setToolbarHidden(false, animated: true)
        addUndoObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Setups
    
    private func setupViews() {
        view.addSubview(imageView)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        imageView.frame.size = imageView.sizeThatFits(view.frame.size)
        imageView.center = view.center
    }
    
    private func setupToolbar() {
        navigationController?.toolbar.isTranslucent = false
        
        toolbarItems = []
        
        if enhancedImageIsAvailable {
            toolbarItems!.append(enhanceButton)
        }
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems!.append(flexibleSpace)
        toolbarItems!.append(undoButton)
    }
    
    // MARK: - Actions
    
    @objc private func toggleEnhancedImage() {
        guard enhancedImageIsAvailable else { return }
        if isCurrentlyDisplayingEnhancedImage {
            imageView.image = results.scannedImage
            enhanceButton.tintColor = .black
        } else {
            imageView.image = results.enhancedImage
            enhanceButton.tintColor = UIColor(red: 64 / 255, green: 159 / 255, blue: 255 / 255, alpha: 1.0)
        }
        
        isCurrentlyDisplayingEnhancedImage.toggle()
    }
    
    @objc func tapUndoImage() {
        undoManager?.undo()
    }
    
    @objc private func finishScan() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        var newResults = results
        newResults.markupImage = imageView.markupImage
        newResults.scannedImage = results.scannedImage
        newResults.doesUserPreferEnhancedImage = isCurrentlyDisplayingEnhancedImage
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFinishScanningWithResults: newResults)
    }
}

extension ReviewViewController: MarkupImageViewDelegate {
    func markupImageDidFinishLine() {
        didUndoChange()
    }
}
