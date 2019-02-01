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
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        
        markupLayer.frame = layer.bounds
        
        let scale:CGFloat
        if let image = image, bounds.width > 0 {
            scale = image.size.width / bounds.width
        } else {
            scale = UIScreen.main.scale
        }
        
        markupLayer.contentsScale = scale
    }
    
    func setupGesture() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan))
        panRecognizer.maximumNumberOfTouches = 1
        addGestureRecognizer(panRecognizer)
    }
    
    @objc func handlePan(g:UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            markupLayer.lines.append([])
            fallthrough
        case .changed:
            let point = g.location(in: self)
            markupLayer.lines[markupLayer.lines.count - 1].append(point)
        default:
            undoManager?.registerUndo(withTarget: self) { target in
                self.markupLayer.lines.removeLast()
                self.markupLayer.setNeedsDisplay()
            }
            delegate?.markupImageDidFinishLine()
        }
        
        markupLayer.setNeedsDisplay()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let image = image else { return size }
        guard image.size.width > 0 && image.size.height > 0 else { return size }
        
        let scale = min(size.width / image.size.width, size.height / image.size.height)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
}

class MarkupLayer: CALayer {
    
    var lines:[[CGPoint]] = []
    
    var image:UIImage? {
        guard lines.count > 0 else { return nil }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = contentsScale
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        return renderer.image { ctx in
            self.draw(in: ctx.cgContext)
        }
    }
    
    override init() {
        super.init()
        
        masksToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(in ctx: CGContext) {
        ctx.beginPath()
        ctx.setStrokeColor(UIColor(red: 2/255, green: 190/255, blue: 216/255, alpha: 1).cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(2)
        
        for line in lines {
            guard line.count > 0 else { continue }
            
            ctx.move(to: line.first!)
            
            for (i, point) in line.enumerated() {
                guard i != 0 else { continue }
                ctx.addQuadCurve(to: point, control: line[i - 1])
            }
        }
        
        ctx.strokePath()
    }
    
}
