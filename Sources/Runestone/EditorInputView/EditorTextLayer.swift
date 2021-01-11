//
//  File.swift
//  
//
//  Created by Simon Støvring on 06/01/2021.
//

import UIKit

final class EditorTextLayer {
    var font: UIFont? {
        didSet {
            if font != oldValue {
                updateFont()
            }
        }
    }
    var constrainingWidth: CGFloat = .greatestFiniteMagnitude {
        didSet {
            if constrainingWidth != oldValue {
                _preferredSize = nil
            }
        }
    }
    var preferredSize: CGSize {
        if let preferredSize = _preferredSize {
            return preferredSize
        } else if isEmpty, let font = font {
            let height = font.lineHeight
            let preferredSize = CGSize(width: constrainingWidth, height: height)
            _preferredSize = preferredSize
            return preferredSize
        } else if let framesetter = framesetter {
            let constrainingSize = CGSize(width: constrainingWidth, height: .greatestFiniteMagnitude)
            let preferredSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constrainingSize, nil)
            _preferredSize = preferredSize
            return preferredSize
        } else if let font = font {
            let preferredSize = CGSize(width: constrainingWidth, height: font.lineHeight)
            _preferredSize = preferredSize
            return preferredSize
        } else {
            return .zero
        }
    }
    var origin: CGPoint = .zero {
        didSet {
            if origin != oldValue {
                _textFrame = nil
            }
        }
    }

    private var attributedString: CFMutableAttributedString?
    private var framesetter: CTFramesetter? {
        if let framesetter = _framesetter {
            return framesetter
        } else if let attributedString = attributedString {
            _framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            return _framesetter
        } else {
            return nil
        }
    }
    private var textFrame: CTFrame? {
        if let frame = _textFrame {
            return frame
        } else if let framesetter = framesetter {
            let path = CGMutablePath()
            path.addRect(CGRect(x: origin.x, y: origin.y, width: preferredSize.width, height: preferredSize.height))
            _textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            return _textFrame
        } else {
            return nil
        }
    }
    private var _framesetter: CTFramesetter?
    private var _textFrame: CTFrame?
    private var _preferredSize: CGSize?
    private var isEmpty = true

    func setString(_ string: NSString) {
        _preferredSize = nil
        _framesetter = nil
        _textFrame = nil
        isEmpty = string.length == 0
        attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.length)
        if let attributedString = attributedString {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string)
            updateFont()
        }
    }

    func draw(in context: CGContext) {
        if let textFrame = textFrame {
            CTFrameDraw(textFrame, context)
        }
    }

    func caretRect(aIndex index: Int) -> CGRect {
        let caretWidth: CGFloat = 3
        guard let textFrame = textFrame else {
            return CGRect(x: origin.x, y: origin.y, width: caretWidth, height: font?.lineHeight ?? 0)
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        for lineIndex in 0 ..< lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
            let lineRange = CTLineGetStringRange(line)
            if index >= 0 && index <= lineRange.location + lineRange.length {
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                let height = ascent + descent
                let xPos = CTLineGetOffsetForStringIndex(line, index, nil)
                return CGRect(x: xPos, y: origin.y, width: caretWidth, height: height)
            }
        }
        return CGRect(x: origin.x, y: origin.y, width: caretWidth, height: font?.lineHeight ?? 0)
    }

    func firstRect(for range: NSRange) -> CGRect? {
        guard let textFrame = textFrame else {
            return nil
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        for lineIndex in 0 ..< lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
            let lineRange = CTLineGetStringRange(line)
            let index = range.location
            if index >= 0 && index <= lineRange.length {
                let finalIndex = min(lineRange.location + lineRange.length, range.location + range.length)
                let xStart = CTLineGetOffsetForStringIndex(line, index, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, nil)
                var origin: CGPoint = .zero
                CTFrameGetLineOrigins(textFrame, CFRangeMake(lineIndex, 0), &origin)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                let height = ascent + descent
                let yPos = origin.y - descent
                return CGRect(x: xStart, y: yPos, width: xEnd - xStart, height: height)
            }
        }
        return nil
    }

    func closestIndex(to point: CGPoint) -> Int? {
        guard let textFrame = textFrame else {
            return nil
        }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        var origins: [CGPoint] = Array(repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(textFrame, CFRangeMake(0, lineCount), &origins)
        for lineIndex in 0 ..< lineCount {
            if point.y > origins[lineIndex].y {
                // This line is closest to the y-coordinate. Now we find the closest string index in the line.
                let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex)!, to: CTLine.self)
                return CTLineGetStringIndexForPosition(line, point)
            }
        }
        // Fallback to max index.
        let range = CTFrameGetStringRange(textFrame)
        return range.length
    }
}

private extension EditorTextLayer {
    private func updateFont() {
        if let font = font, let attributedString = attributedString {
            let length = CFAttributedStringGetLength(attributedString)
            CFAttributedStringSetAttribute(attributedString, CFRangeMake(0, length), kCTFontAttributeName, font)
        }
    }
}
