//
//  AudioVisualizer.swift
//  SimpleAudioRecorder
//
//  Created by Dimitri Bouniol Lambda on 1/16/20.
//  Copyright © 2020 Lambda, Inc. All rights reserved.
//

import UIKit

@IBDesignable
public class AudioVisualizer: UIView {
    
    // MARK: IBInspectable Properties
    
    /// The width of a bar in points.
    @IBInspectable public var barWidth: CGFloat = 10 {
        didSet {
            updateBars()
        }
    }
    
    /// The corner radius of a bar in points. If less than `0`, then it will default to half of the width of the bar.
    @IBInspectable public var barCornerRadius: CGFloat = -1 {
        didSet {
            updateBars()
        }
    }
    
    /// The spacing between bars in points.
    @IBInspectable public var barSpacing: CGFloat = 4 {
        didSet {
            updateBars()
        }
    }
    
    /// The color of a bar.
    @IBInspectable public var barColor: UIColor = .systemGray {
        didSet {
            for bar in bars {
                bar.backgroundColor = barColor
            }
        }
    }
    
    /// The amount of time before a bar decays into the adjacent spot
    @IBInspectable public var decaySpeed: Double = 0.01 {
        didSet {
            decayTimer?.invalidate()
            decayTimer = nil
        }
    }
    
    /// The fraction the newest value will decay by if not updated by the time a decay starts
    @IBInspectable public var decayAmount: Double = 0.8
    
    // MARK: Internal Properties
    
    private var bars = [UIView]()
    private var values = [Double]()
    
    private weak var decayTimer: Timer?
    private var newestValue: Double = 0
    
    // MARK: - Object Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        #if TARGET_INTERFACE_BUILDER
        values = [0.7, 0.2, 0.9, 0.8, 0.76, 0.4, 0.2, 0.3, 0.4, 0.76, 0.4, 0.2, 0.3, 0.4, 0.76, 0.4, 0.2, 0.3, 0.4, 0.76, 0.4, 0.2, 0.3, 0.4]
        #endif
        
        // Build the inner bars
        self.updateBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        // Build the inner bars
        self.updateBars()
    }
    
    deinit {
        // Invalidate the timer if it is still active
        decayTimer?.invalidate()
    }
    
    // MARK: - Layout
    override public func layoutSubviews() {
        updateBars()
    }
    
    private func updateBars() {
        // Clean up old bars
        for bar in bars {
            bar.removeFromSuperview()
        }
        
        var newBars = [UIView]()
        
        // Calculate number of bars we will be able to display
        var numberOfBarsToCreate = Int(bounds.width/(barWidth + barSpacing))
        
        // Helper function for creating bars
        func createBar(_ positionFromCenter: Int) {
            let bar = UIView(frame: frame(forBar: positionFromCenter))
            bar.backgroundColor = barColor
            bar.layer.cornerRadius = (barCornerRadius < 0 || barCornerRadius > barWidth/2) ? floor(barWidth/2) : barCornerRadius
            
            numberOfBarsToCreate -= 1
            newBars.append(bar)
            self.addSubview(bar)
        }
        
        // Create the center bar
        createBar(0)
        
        // Keep creating bars in pairs until there is no more room
        var position = 1
        while numberOfBarsToCreate > 0 {
            // Create the symmetric pairs of bars starting from the center
            createBar(-position)
            createBar(position)
            
            position += 1
        }
        
        bars = newBars
    }
    
    /// Calculate the frame of a particular bar
    /// - Parameter positionFromCenter: The distance of the bar from the center (which is 0)
    private func frame(forBar positionFromCenter: Int) -> CGRect {
        let valueIndex = Int(positionFromCenter.magnitude)
        
        return frame(forBar: positionFromCenter, value: (valueIndex < values.count) ? values[valueIndex] : 0)
    }
    
    /// Calculate the frame of a particular bar, specifying a value
    /// - Parameter positionFromCenter: The distance of the bar from the center (which is 0)
    private func frame(forBar positionFromCenter: Int, value: Double) -> CGRect {
        let maxValue = (1 - CGFloat(positionFromCenter.magnitude)*(barWidth + barSpacing)/bounds.width/2)*bounds.height/2
        let height = CGFloat(value)*maxValue
        
        return CGRect(x: floor(bounds.width/2) + CGFloat(positionFromCenter)*(barWidth + barSpacing) - barWidth/2, y: floor(bounds.height/2) - height, width: barWidth, height: height*2)
    }
    
    // MARK: - Animation
    
    /// Start the decay timer, but only if if hasn't been created yet
    private func startTimer() {
        guard decayTimer == nil else { return }
        
        decayTimer = Timer.scheduledTimer(withTimeInterval: decaySpeed, repeats: true) { [weak self] (_) in
            guard let self = self else { return }
            
            self.decayNewestValue()
        }
    }
    
    private func decayNewestValue() {
        values.insert(newestValue, at: 0)
        
        // Trim the end of the values array if there are too many for the number of bars
        let currentCount = values.count
        let maxCount = bars.count/2 + 1
        if currentCount > maxCount {
            values.removeSubrange(maxCount ..< currentCount)
        }
        
        // Update the frames of each bar
        for (positionFromCenter, value) in values.enumerated() {
            if positionFromCenter == 0 {
                bars[0].frame = frame(forBar: positionFromCenter, value: value)
            } else {
                bars[positionFromCenter*2 - 1].frame = frame(forBar: -positionFromCenter, value: value)
                bars[positionFromCenter*2].frame = frame(forBar: positionFromCenter, value: value)
            }
        }
        
        // Decay the newest value
        newestValue = newestValue*decayAmount
        
        // Check if the values are empty
        let totalValue = values.reduce(0.0) { $0 + $1 }
        if totalValue <= 0.000001 {
            decayTimer?.invalidate()
            decayTimer = nil
        }
    }
    
    // MARK: - Public Methods
    
    /// Add a value to the visualizer. Be sure to call `AVAudioPlayer.isMeteringEnabled = true`, and `AVAudioPlayer.updateMeters()` before every call to `AVAudioPlayer.averagePower(forChannel: 0)`
    /// - Parameter decibleValue: The value you would get out of `AVAudioPlayer.averagePower(forChannel: 0)`
    public func addValue(decibleValue: Float) {
        addValue(decibleValue: Double(decibleValue))
    }
    
    /// Add a value to the visualizer. Be sure to call `AVAudioPlayer.isMeteringEnabled = true`, and `AVAudioPlayer.updateMeters()` before every call to `AVAudioPlayer.averagePower(forChannel: 0)`
    /// - Parameter decibleValue: The value you would get out of `AVAudioPlayer.averagePower(forChannel: 0)`
    public func addValue(decibleValue: Double) {
        let normalizedValue = __exp10(decibleValue/20)
        
        newestValue = normalizedValue
        
        startTimer()
    }

}
