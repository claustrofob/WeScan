//
//  MarkupView.swift
//  WeScan
//
//  Created by Claus on 1/31/19.
//  Copyright © 2019 WeTransfer. All rights reserved.
//

import UIKit

protocol MarkupImageViewDelegate:class {
    func markupImageDidFinishLine()
}

class MarkupImageView: UIImageView {
    
    weak var delegate:MarkupImageViewDelegate?
    
    var markupImage:UIImage? {
        return markupLayer.image
    }
    
    let markupLayer = MarkupLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    func setup() {
        clipsToBounds = true
        contentMode = .scaleAspectFill
        isUserInteractionEnabled = true
        
        layer.addSublayer(markupLayer)
        
        setupGesture()
    }
    
    var originalScale:CGFloat {
        let scale:CGFloat
        if let image = image, bounds.width > 0 {
            scale = image.size.width / bounds.width
        } else {
            scale = UIScreen.main.scale
        }
        return scale
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        
        markupLayer.frame = layer.bounds
        markupLayer.contentsScale = originalScale
    }
    
    func setupGesture() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan))
        panRecognizer.maximumNumberOfTouches = 1
        addGestureRecognizer(panRecognizer)
    }
    
    @objc func handlePan(g:UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            let point = g.location(in: self)
            markupLayer.start(point: point)
            fallthrough
        case .changed:
            let point = g.location(in: self)
            markupLayer.add(point: point)
        default:
            undoManager?.registerUndo(withTarget: self) { target in
                self.markupLayer.undoLastPath()
            }
            delegate?.markupImageDidFinishLine()
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let image = image else { return size }
        guard image.size.width > 0 && image.size.height > 0 else { return size }
        
        let scale = min(size.width / image.size.width, size.height / image.size.height)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
}

class MarkupLayer: CALayer {
    
    var lines:[UIBezierPath] = []
    
    var image:UIImage? {
        guard lines.count > 0 else { return nil }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = contentsScale
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        return renderer.image { ctx in
            self.render(in: ctx.cgContext)
        }
    }
    
    override init() {
        super.init()
        
        masksToBounds = true
        sublayers = []
    }
    
    public func start(point: CGPoint) {
        let path = UIBezierPath()
        path.move(to: point)
        lines.append(path)
        
        let shape = shapeLayer
        addShape(shape: shape)
    }
    
    public func add(point: CGPoint) {
        let line = lines[lines.count - 1]
        line.addQuadCurve(to: point, controlPoint: line.currentPoint)
        
        let layer = sublayers!.last as! CAShapeLayer
        layer.path = line.cgPath
    }
    
    public func undoLastPath() {
        lines.removeLast()
        sublayers?.removeLast()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        
        if let sublayers = sublayers {
            for layer in sublayers {
                layer.frame = self.bounds
                layer.contentsScale = contentsScale
            }
        }
    }
    
    var shapeLayer:CAShapeLayer {
        let shape = CAShapeLayer()
        shape.strokeColor = UIColor(red: 2/255, green: 190/255, blue: 216/255, alpha: 0.7).cgColor
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.lineWidth = 8
        shape.fillColor = UIColor.clear.cgColor
        return shape
    }
    
    func addShape(shape:CAShapeLayer) {
        shape.frame = bounds
        addSublayer(shape)
    }
}
