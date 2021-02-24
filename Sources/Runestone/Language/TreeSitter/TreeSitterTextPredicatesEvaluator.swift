//
//  TreeSitterPredicatesValidator.swift
//  
//
//  Created by Simon Støvring on 23/02/2021.
//

import Foundation

protocol TreeSitterTextPredicatesEvaluatorDelegate: AnyObject {
    func treeSitterTextPredicatesEvaluator(_ evaluator: TreeSitterTextPredicatesEvaluator, stringIn byteRange: ByteRange) -> String
}

final class TreeSitterTextPredicatesEvaluator {
    weak var delegate: TreeSitterTextPredicatesEvaluatorDelegate?

    private let match: TreeSitterQueryMatch

    init(match: TreeSitterQueryMatch) {
        self.match = match
    }

    func evaluatePredicates(in capture: TreeSitterCapture) -> Bool {
        guard !capture.textPredicates.isEmpty else {
            return true
        }
        for textPredicate in capture.textPredicates {
            switch textPredicate {
            case .captureEqualsString(let parameters):
                if !evaluate(using: parameters) {
                    return false
                }
            case .captureEqualsCapture(let parameters):
                if !evaluate(using: parameters) {
                    return false
                }
            case .captureMatchesPattern(let parameters):
                if !evaluate(using: parameters) {
                    return false
                }
            }
        }
        return true
    }
}

private extension TreeSitterTextPredicatesEvaluator {
    func evaluate(using parameters: TreeSitterTextPredicate.CaptureEqualsStringParameters) -> Bool {
        guard let capture = match.capture(forIndex: parameters.captureIndex) else {
            return false
        }
        guard let contentText = string(in: capture.byteRange) else {
            return false
        }
        let comparisonResult = contentText == parameters.string
        return comparisonResult == parameters.isPositive
    }

    func evaluate(using parameters: TreeSitterTextPredicate.CaptureEqualsCaptureParameters) -> Bool {
        guard let lhsCapture = match.capture(forIndex: parameters.lhsCaptureIndex) else {
            return false
        }
        guard let rhsCapture = match.capture(forIndex: parameters.lhsCaptureIndex) else {
            return false
        }
        guard let lhsContentText = string(in: lhsCapture.byteRange) else {
            return false
        }
        guard let rhsContentText = string(in: rhsCapture.byteRange) else {
            return false
        }
        let comparisonResult = lhsContentText == rhsContentText
        return comparisonResult == parameters.isPositive
    }

    func evaluate(using parameters: TreeSitterTextPredicate.CaptureMatchesPatternParameters) -> Bool {
        guard let capture = match.capture(forIndex: parameters.captureIndex) else {
            return false
        }
        guard let contentText = string(in: capture.byteRange) else {
            return false
        }
        let matchingRange = contentText.range(of: parameters.pattern, options: .regularExpression)
        let isMatch = matchingRange != nil
        return isMatch == parameters.isPositive
    }

    private func string(in byteRange: ByteRange) -> String? {
        return delegate?.treeSitterTextPredicatesEvaluator(self, stringIn: byteRange)
    }
}
