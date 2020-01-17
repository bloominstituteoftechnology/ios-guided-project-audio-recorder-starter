//
//  AudioVisualizer.swift
//  SimpleAudioRecorder
//
//  Created by Dimitri Bouniol Lambda on 1/16/20.
//  Copyright © 2020 Lambda, Inc. All rights reserved.
//

import UIKit

class AudioVisualizer: UIView {
    
    private var barWidth: CGFloat = 10
    private var barSpacing: CGFloat = 4
    
    private var bars = [UIView]()
    private var values = [Double]()
    
    private weak var timer: Timer?
    private var newestValue: Double = 0
    
    // MARK: - Object Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.updateBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.updateBars()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        updateBars()
    }
    
    private func updateBars() {
        // Clean up old bars
        for bar in bars {
            bar.removeFromSuperview()
        }
        
        var newBars = [UIView]()
        
        // Calculate number of bars we will be able to display
        var numberOfBars = Int(bounds.width/(barWidth + barSpacing))
        
        // Helper function for creating bars
        func createBar(_ positionFromCenter: Int) {
            let maxValue = (1 - CGFloat(positionFromCenter.magnitude)*(barWidth + barSpacing)/bounds.width/2)*bounds.height/2
            var height: CGFloat!
            
            if positionFromCenter.magnitude < values.count {
                height = round(CGFloat(values[Int(positionFromCenter.magnitude)])*maxValue)
            } else {
                height = 0
            }
            
            
            let bar = UIView(frame: CGRect(x: floor(bounds.width/2) + CGFloat(positionFromCenter)*(barWidth + barSpacing) - barWidth/2, y: floor(bounds.height/2) - height, width: barWidth, height: height*2))
            bar.backgroundColor = .systemGray
            bar.layer.cornerRadius = floor(barWidth/2)
            
            numberOfBars -= 1
            newBars.append(bar)
            self.addSubview(bar)
        }
        
        // Create the center bar
        createBar(0)
        
        // Keep creating bars in pairs until there is no more room
        var position = 1
        while numberOfBars > 0 {
            
            createBar(-position)
            createBar(position)
            
            position += 1
        }
        
        bars = newBars
    }
    
    // MARK: - Animation
    private func startTimer() {
        guard timer == nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] (_) in
            guard let self = self else { return }
            self.moveRecentValueDown()
            
            
        }
    }
    
    private func moveRecentValueDown() {
        values.insert(newestValue, at: 0)
        
        let currentCount = values.count
        let maxCount = bars.count/2 + 1
        if currentCount > maxCount {
            values.removeSubrange(maxCount ..< currentCount)
        }
        
        for (positionFromCenter, value) in values.enumerated() {
            let maxValue = (1.0 - CGFloat(positionFromCenter.magnitude)*(barWidth + barSpacing)/bounds.width/2)*bounds.height/2
            
            let height = CGFloat(value)*maxValue
            
            if positionFromCenter == 0 {
                bars[0].frame = CGRect(x: floor(bounds.width/2) + CGFloat(positionFromCenter)*(barWidth + barSpacing) - barWidth/2, y: floor(bounds.height/2) - height, width: barWidth, height: height*2)
            } else {
                bars[positionFromCenter*2 - 1].frame = CGRect(x: floor(bounds.width/2) + CGFloat(-positionFromCenter)*(barWidth + barSpacing) - barWidth/2, y: floor(bounds.height/2) - height, width: barWidth, height: height*2)
                bars[positionFromCenter*2].frame = CGRect(x: floor(bounds.width/2) + CGFloat(positionFromCenter)*(barWidth + barSpacing) - barWidth/2, y: floor(bounds.height/2) - height, width: barWidth, height: height*2)
            }
        }
        
        newestValue = newestValue*0.8
        if let lastValue = self.values.last, lastValue <= 0.000001 {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - Public
    
    /// Add a value to the visualizer
    /// - Parameter decibleValue: The value you would get out of AVAudioPlayer.averagePower(forChannel: 0)
    func addValue(decibleValue: Float) {
        addValue(decibleValue: Double(decibleValue))
    }
    
    /// Add a value to the visualizer
    /// - Parameter decibleValue: The value you would get out of AVAudioPlayer.averagePower(forChannel: 0)
    func addValue(decibleValue: Double) {
        let normalizedValue = __exp10(decibleValue/20)
        
        newestValue = normalizedValue
        
        startTimer()
    }

}
