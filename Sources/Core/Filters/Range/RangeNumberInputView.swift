//
//  Copyright © FINN.no AS, Inc. All rights reserved.
//

import UIKit

protocol RangeNumberInputViewDelegate: AnyObject {
    func rangeNumberInputView(_ view: RangeNumberInputView, didChangeLowValue value: Int?)
    func rangeNumberInputView(_ view: RangeNumberInputView, didChangeHighValue value: Int?)
}

final class RangeNumberInputView: UIView {
    enum InputFontSize: CGFloat {
        case large = 30
        case small = 24
    }

    private enum InputGroup {
        case lowValue, highValue
    }

    weak var delegate: RangeNumberInputViewDelegate?
    var generatesHapticFeedbackOnValueChange = true
    var accessibilityValueSuffix: String?

    private let minimumValue: Int
    private let maximumValue: Int
    private let unit: String
    private let formatter: RangeFilterValueFormatter
    private var inputFontSize: CGFloat
    private let displaysUnitInNumberInput: Bool
    private let lowValueInputDecorationViewConstraintIdentifier = "lowValueInputDecorationViewConstraintIdentifier"
    private let highValueInputDecorationViewConstraintIdentifier = "highValueInputDecorationViewConstraintIdentifier"
    private var inputValues = [InputGroup: Int]()
    private var inputValidationStatus = [InputGroup: Bool]()

    // MARK: - Views

    private lazy var lowValueInputTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.textColor = Style.textColor
        textField.font = Style.normalFont(size: inputFontSize)
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.accessibilityLabel = "range_number_input_view_low_value_textfield_accessibility_label".localized()
        return textField
    }()

    private lazy var lowValueInputUnitLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = Style.textColor
        label.addGestureRecognizer(makeGestureRecognizer())
        label.isUserInteractionEnabled = true
        label.isAccessibilityElement = false
        return label
    }()

    private lazy var underLowerBoundHintLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "range_below_lower_bound_title".localized()
        label.font = Style.hintNormalFont
        label.textColor = Style.textColor
        return label
    }()

    private lazy var inputSeparatorView: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "-"
        label.textColor = Style.textColor
        label.font = Style.normalFont(size: inputFontSize)

        return label
    }()

    private lazy var highValueInputTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textColor = Style.textColor
        textField.font = Style.normalFont(size: inputFontSize)
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.accessibilityLabel = "range_number_input_view_high_value_textfield_accessibility_label".localized()
        return textField
    }()

    private lazy var highValueInputUnitLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = Style.textColor
        label.addGestureRecognizer(makeGestureRecognizer())
        label.isUserInteractionEnabled = true
        label.isAccessibilityElement = false
        return label
    }()

    private lazy var overUpperBoundHintLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "range_above_upper_bound_title".localized()
        label.font = Style.hintNormalFont
        label.textColor = Style.textColor
        return label
    }()

    private lazy var lowValueInputDecorationView: UIView = {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Style.decorationViewColor
        view.addGestureRecognizer(makeGestureRecognizer())
        return view
    }()

    private lazy var highValueInputDecorationView: UIView = {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Style.decorationViewColor
        view.addGestureRecognizer(makeGestureRecognizer())
        return view
    }()

    private lazy var inputGroupMap: [UIView: InputGroup] = {
        return [
            lowValueInputTextField: .lowValue,
            lowValueInputUnitLabel: .lowValue,
            lowValueInputDecorationView: .lowValue,
            highValueInputTextField: .highValue,
            highValueInputUnitLabel: .highValue,
            highValueInputDecorationView: .highValue,
        ]
    }()

    // MARK: - Init

    init(minimumValue: Int, maximumValue: Int, unit: String, formatter: RangeFilterValueFormatter,
         inputFontSize: InputFontSize = .large, displaysUnitInNumberInput: Bool = true) {
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.unit = unit
        self.formatter = formatter
        self.inputFontSize = inputFontSize.rawValue
        self.displaysUnitInNumberInput = displaysUnitInNumberInput
        super.init(frame: .zero)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Overrides

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.point(inside: point, with: event) else {
            _ = resignFirstResponder()
            return nil
        }

        for subview in subviews {
            let convertedPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(convertedPoint, with: event) {
                return hitView
            }
        }

        return nil
    }

    override var isFirstResponder: Bool {
        return lowValueInputTextField.isFirstResponder || highValueInputTextField.isFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        if lowValueInputTextField.isFirstResponder {
            lowValueInputTextField.resignFirstResponder()
        } else if highValueInputTextField.isFirstResponder {
            highValueInputTextField.resignFirstResponder()
        }

        return super.resignFirstResponder()
    }
}

// MARK: - Input

extension RangeNumberInputView {
    var lowValue: Int? {
        return inputValues[.lowValue]
    }

    var highValue: Int? {
        return inputValues[.highValue]
    }

    func setLowValue(_ value: Int, animated: Bool) {
        let valueText = text(from: value)
        lowValueInputTextField.text = valueText
        lowValueInputTextField.accessibilityValue = "\(valueText) \(accessibilityValueSuffix ?? "")"
        inputValues[.lowValue] = value == minimumValue ? nil : value
        validateInputs(activeInputGroup: .lowValue)
    }

    func setHighValue(_ value: Int, animated: Bool) {
        let valueText = text(from: value)
        highValueInputTextField.text = valueText
        highValueInputTextField.accessibilityValue = "\(valueText) \(accessibilityValueSuffix ?? "")"
        inputValues[.highValue] = value == maximumValue ? nil : value
        validateInputs(activeInputGroup: .highValue)
    }

    func setLowValueHint(text: String) {
        setHintText(text, for: .lowValue)
    }

    func setHighValueHint(text: String) {
        setHintText(text, for: .highValue)
    }

    func forceSmallInputFontSize() {
        inputFontSize = InputFontSize.small.rawValue
        lowValueInputTextField.font = lowValueInputTextField.isFirstResponder ? Style.activeFont(size: inputFontSize) : Style.normalFont(size: inputFontSize)
        lowValueInputUnitLabel.font = lowValueInputTextField.font
        highValueInputTextField.font = highValueInputTextField.isFirstResponder ? Style.activeFont(size: inputFontSize) : Style.normalFont(size: inputFontSize)
        highValueInputUnitLabel.font = highValueInputTextField.font
    }

    private func validateInputs(activeInputGroup: InputGroup) {
        let inactiveInputGroup: InputGroup = activeInputGroup == .lowValue ? .highValue : .lowValue

        updateValidationStatus(for: activeInputGroup, isValid: isValidValue(for: activeInputGroup))
        updateValidationStatus(for: inactiveInputGroup, isValid: true)
    }

    private func updateValidationStatus(for inputGroup: InputGroup, isValid: Bool, generateHapticFeedback: Bool = false) {
        let textColor = isValid ? Style.textColor : Style.errorTextColor

        switch inputGroup {
        case .lowValue:
            lowValueInputTextField.textColor = textColor
            lowValueInputUnitLabel.textColor = textColor
        case .highValue:
            highValueInputTextField.textColor = textColor
            highValueInputUnitLabel.textColor = textColor
        }

        let isCurrentValueValid = inputValidationStatus[inputGroup] ?? true
        let useHaptics = generateHapticFeedback && generatesHapticFeedbackOnValueChange

        if !isValid && isCurrentValueValid && useHaptics {
            FeedbackGenerator.generate(.error)
        }

        inputValidationStatus[inputGroup] = isValid
    }

    private func isValidValue(for inputGroup: InputGroup) -> Bool {
        guard let lowValue = lowValue, let highValue = highValue else {
            return true
        }

        switch inputGroup {
        case .highValue:
            return lowValue <= highValue
        case .lowValue:
            return highValue >= lowValue
        }
    }
}

// MARK: - UITextFieldDelegate

extension RangeNumberInputView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let inputGroup = inputGroupMap[textField] else {
            return
        }

        handleInteraction(with: inputGroup)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let inputGroup = inputGroupMap[textField] else {
            return
        }

        setInputGroup(inputGroup, active: false)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var text = textField.text ?? ""

        guard let stringRange = Range<String.Index>(range, in: text) else {
            return false
        }

        text.replaceSubrange(stringRange, with: string)
        text.removeWhitespaces()

        if text.isEmpty {
            text = "\(minimumValue)"
        }

        guard let inputGroup = inputGroupMap[textField] else {
            return false
        }

        guard let newValue = Int(text) else {
            return false
        }

        textField.text = self.text(from: newValue)
        textField.accessibilityValue = "\(newValue) \(accessibilityValueSuffix ?? "")"

        inputValues[inputGroup] = newValue
        updateValidationStatus(for: inputGroup, isValid: isValidValue(for: inputGroup), generateHapticFeedback: true)

        switch inputGroup {
        case .lowValue:
            delegate?.rangeNumberInputView(self, didChangeLowValue: newValue)
        case .highValue:
            delegate?.rangeNumberInputView(self, didChangeHighValue: newValue)
        }

        return false
    }
}

// MARK: - Setup

extension RangeNumberInputView {
    private func setup() {
        let valueText = text(from: minimumValue)

        lowValueInputTextField.text = valueText
        lowValueInputTextField.inputAccessoryView = UIToolbar(target: self, nextTextField: highValueInputTextField)
        lowValueInputTextField.accessibilityValue = "\(valueText) \(accessibilityValueSuffix ?? "")"

        highValueInputTextField.text = valueText
        highValueInputTextField.inputAccessoryView = UIToolbar(target: self, previousTextField: lowValueInputTextField)
        highValueInputTextField.accessibilityValue = "\(valueText) \(accessibilityValueSuffix ?? "")"

        if displaysUnitInNumberInput {
            lowValueInputUnitLabel.attributedText = attributedUnitText(withFont: Style.normalFont(size: inputFontSize), from: unit)
            highValueInputUnitLabel.attributedText = attributedUnitText(withFont: Style.normalFont(size: inputFontSize), from: unit)
        }

        addSubview(underLowerBoundHintLabel)
        addSubview(lowValueInputTextField)
        addSubview(lowValueInputUnitLabel)
        addSubview(inputSeparatorView)
        addSubview(overUpperBoundHintLabel)
        addSubview(highValueInputTextField)
        addSubview(highValueInputUnitLabel)
        addSubview(lowValueInputDecorationView)
        addSubview(highValueInputDecorationView)

        let lowValueInputDecorationViewConstraint = lowValueInputDecorationView.heightAnchor.constraint(equalToConstant: Style.decorationViewHeight)
        lowValueInputDecorationViewConstraint.identifier = lowValueInputDecorationViewConstraintIdentifier
        let highValueInputDecorationViewConstraint = highValueInputDecorationView.heightAnchor.constraint(equalToConstant: Style.decorationViewHeight)
        highValueInputDecorationViewConstraint.identifier = highValueInputDecorationViewConstraintIdentifier

        NSLayoutConstraint.activate([
            underLowerBoundHintLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            underLowerBoundHintLabel.centerXAnchor.constraint(equalTo: lowValueInputDecorationView.centerXAnchor),
            underLowerBoundHintLabel.bottomAnchor.constraint(equalTo: lowValueInputTextField.topAnchor),

            lowValueInputTextField.topAnchor.constraint(equalTo: topAnchor, constant: .largeSpacing),
            lowValueInputTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            lowValueInputTextField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.mediumSpacing),

            lowValueInputUnitLabel.topAnchor.constraint(equalTo: lowValueInputTextField.topAnchor),
            lowValueInputUnitLabel.leadingAnchor.constraint(equalTo: lowValueInputTextField.trailingAnchor, constant: 0),
            lowValueInputUnitLabel.bottomAnchor.constraint(equalTo: lowValueInputTextField.bottomAnchor),
            lowValueInputUnitLabel.trailingAnchor.constraint(equalTo: inputSeparatorView.leadingAnchor, constant: -.mediumSpacing),

            inputSeparatorView.topAnchor.constraint(equalTo: lowValueInputTextField.topAnchor),
            inputSeparatorView.bottomAnchor.constraint(equalTo: lowValueInputTextField.bottomAnchor),

            overUpperBoundHintLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            overUpperBoundHintLabel.centerXAnchor.constraint(equalTo: highValueInputDecorationView.centerXAnchor),
            overUpperBoundHintLabel.bottomAnchor.constraint(equalTo: highValueInputTextField.topAnchor),

            highValueInputTextField.topAnchor.constraint(equalTo: topAnchor, constant: .largeSpacing),
            highValueInputTextField.leadingAnchor.constraint(equalTo: inputSeparatorView.trailingAnchor, constant: .mediumSpacing),
            highValueInputTextField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.mediumSpacing),

            highValueInputUnitLabel.topAnchor.constraint(equalTo: highValueInputTextField.topAnchor),
            highValueInputUnitLabel.leadingAnchor.constraint(equalTo: highValueInputTextField.trailingAnchor, constant: 0),
            highValueInputUnitLabel.bottomAnchor.constraint(equalTo: highValueInputTextField.bottomAnchor),
            highValueInputUnitLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            lowValueInputDecorationView.leadingAnchor.constraint(equalTo: lowValueInputTextField.leadingAnchor),
            lowValueInputDecorationView.trailingAnchor.constraint(equalTo: lowValueInputUnitLabel.trailingAnchor),
            lowValueInputDecorationView.bottomAnchor.constraint(equalTo: bottomAnchor),
            lowValueInputDecorationViewConstraint,

            highValueInputDecorationView.leadingAnchor.constraint(equalTo: highValueInputTextField.leadingAnchor, constant: .smallSpacing),
            highValueInputDecorationView.trailingAnchor.constraint(equalTo: highValueInputUnitLabel.trailingAnchor),
            highValueInputDecorationView.bottomAnchor.constraint(equalTo: bottomAnchor),
            highValueInputDecorationViewConstraint,
        ])

        lowValueInputTextField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        lowValueInputUnitLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        highValueInputTextField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        highValueInputUnitLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        inputSeparatorView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func text(from value: Int) -> String {
        return formatter.string(from: value) ?? ""
    }

    private func attributedUnitText(withFont font: UIFont?, from string: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .justified
        style.firstLineHeadIndent = .mediumSpacing
        style.headIndent = .mediumSpacing
        style.tailIndent = -.mediumSpacing
        style.lineBreakMode = .byCharWrapping

        let attributes = [
            NSAttributedString.Key.font: font ?? UIFont.systemFont(ofSize: inputFontSize),
            NSAttributedString.Key.paragraphStyle: style,
        ]

        return NSAttributedString(string: string, attributes: attributes)
    }

    private func setHintText(_ text: String, for inputGroup: InputGroup) {
        let hintLabel = inputGroup == .lowValue ? underLowerBoundHintLabel : overUpperBoundHintLabel
        hintLabel.text = text
    }

    @objc private func handleTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let view = gestureRecognizer.view, let inputGroup = inputGroupMap[view] else {
            return
        }

        handleInteraction(with: inputGroup)
    }

    private func handleInteraction(with inputGroup: InputGroup) {
        let otherInputGroup: InputGroup = inputGroup == .lowValue ? .highValue : .lowValue
        setInputGroup(otherInputGroup, active: false)
        setInputGroup(inputGroup, active: true)
        validateInputs(activeInputGroup: lowValueInputTextField.isFirstResponder ? .lowValue : .highValue)
    }

    private func setInputGroup(_ inputGroup: InputGroup, active: Bool) {
        let font: UIFont? = active ? Style.activeFont(size: inputFontSize) : Style.normalFont(size: inputFontSize)
        let outOfRangeBoundsFont = active ? Style.hintActiveFont : Style.hintNormalFont
        let decorationViewColor: UIColor = active ? Style.decorationViewActiveColor : Style.decorationViewColor

        switch inputGroup {
        case .lowValue:
            lowValueInputTextField.font = font

            if displaysUnitInNumberInput {
                lowValueInputUnitLabel.attributedText = attributedUnitText(withFont: lowValueInputTextField.font, from: unit)
            }

            underLowerBoundHintLabel.font = outOfRangeBoundsFont

            let constraint = lowValueInputDecorationView.constraint(withIdentifier: lowValueInputDecorationViewConstraintIdentifier)
            constraint?.constant = active ? Style.decorationViewActiveHeight : Style.decorationViewHeight

            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.lowValueInputDecorationView.backgroundColor = decorationViewColor
                self?.lowValueInputDecorationView.layer.cornerRadius = active ? Style.decorationViewActiveCornerRadius : 0.0
                self?.lowValueInputDecorationView.layoutIfNeeded()
            }
        case .highValue:
            highValueInputTextField.font = font

            if displaysUnitInNumberInput {
                highValueInputUnitLabel.attributedText = attributedUnitText(withFont: highValueInputTextField.font, from: unit)
            }

            overUpperBoundHintLabel.font = outOfRangeBoundsFont

            let constraint = highValueInputDecorationView.constraint(withIdentifier: highValueInputDecorationViewConstraintIdentifier)
            constraint?.constant = active ? Style.decorationViewActiveHeight : Style.decorationViewHeight

            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.highValueInputDecorationView.backgroundColor = decorationViewColor
                self?.highValueInputDecorationView.layer.cornerRadius = active ? Style.decorationViewActiveCornerRadius : 0.0
                self?.highValueInputDecorationView.layoutIfNeeded()
            }
        }

        let inputGroupTextField = inputGroup == .lowValue ? lowValueInputTextField : highValueInputTextField

        if active {
            inputGroupTextField.becomeFirstResponder()
        } else {
            inputGroupTextField.resignFirstResponder()
        }
    }

    private func makeGestureRecognizer() -> UITapGestureRecognizer {
        let tapGestureRecognizer = UITapGestureRecognizer()
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.addTarget(self, action: #selector(handleTapGesture(_:)))
        return tapGestureRecognizer
    }
}

// MARK: - Styles

private struct Style {
    static let textColor: UIColor = .licorice
    static let errorTextColor: UIColor = .cherry
    static func normalFont(size: CGFloat) -> UIFont? { return UIFont(name: FontType.light.rawValue, size: size) }
    static func activeFont(size: CGFloat) -> UIFont? { return UIFont(name: FontType.bold.rawValue, size: size) }
    static let hintNormalFont: UIFont? = UIFont(name: FontType.light.rawValue, size: 16)
    static let hintActiveFont: UIFont? = UIFont(name: FontType.medium.rawValue, size: 16)
    static let decorationViewColor: UIColor = .stone
    static let decorationViewActiveColor: UIColor = .primaryBlue
    static let decorationViewHeight: CGFloat = 1.0
    static let decorationViewActiveHeight: CGFloat = 3.0
    static let decorationViewActiveCornerRadius = decorationViewActiveHeight / 2
}

// MARK: - Private extensions

private extension UIView {
    func constraint(withIdentifier identifier: String) -> NSLayoutConstraint? {
        return constraints.first(where: { $0.identifier == identifier })
    }
}

private extension String {
    mutating func removeWhitespaces() {
        let components = self.components(separatedBy: .whitespaces)
        self = components.joined(separator: "")
    }
}

private extension UIToolbar {
    convenience init(target: UIView, previousTextField: UITextField? = nil, nextTextField: UITextField? = nil) {
        self.init()

        let items: [RangeToolbarItem] = [
            .arrow(imageAsset: .arrowLeft, target: previousTextField),
            .fixedSpace(width: .mediumLargeSpacing),
            .arrow(imageAsset: .arrowRight, target: nextTextField),
            .flexibleSpace,
            .done(target: target),
        ]

        sizeToFit()
        setItems(items.map({ $0.buttonItem }), animated: false)
    }
}
