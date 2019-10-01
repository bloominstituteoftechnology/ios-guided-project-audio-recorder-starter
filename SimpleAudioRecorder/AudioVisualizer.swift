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
        
        initialSetup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        initialSetup()
    }
    
    func initialSetup() {
        // Pre-fill values for Interface Builder preview
        #if TARGET_INTERFACE_BUILDER
        values = [
            0.19767167952644904,
            0.30975147553721694,
            0.2717680681330001,
            0.25914398105158504,
            0.3413322535900626,
            0.311223010327166,
            0.3302641160440099,
            0.303853272136915,
            0.2659123465612464,
            0.2860924489760262,
            0.26477145407733543,
            0.23180693200970012,
            0.24445487891619533,
            0.21484121767935302,
            0.19688917099112885,
            0.19020094289324854,
            0.17402194532721785,
            0.1600055988294578,
            0.15120753744055154,
            0.13789741397752767,
            0.13231033268544698,
            0.1270923459375989,
            0.1121238175344413,
            0.12400069790665748,
            0.24978783142512598,
            0.233063298365594,
            0.5375441947045457,
            0.47456518731446534,
            0.5236630241490436,
            0.4692151822551929,
            0.4255172022748686,
            0.46023063710569184,
            0.42934908823397355,
            0.37221041959882545,
            0.4685050055667653,
            0.4209394065681193,
            0.46643118034506187,
            0.4292307341708633,
            0.3814422662003417,
            0.4386719969186142,
            0.3956598546828729
        ]
        #endif
        
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
        
        
        // Make sure the width of a bar and spacing is greater than 0, and that the available width is also greater than 0
        guard round(barWidth) > 0, barSpacing >= 0, bounds.width > 0, bounds.height > 0 else {
            // Not enough information to create a single bar, so bail early
            bars = []
            return
        }
        
        // Calculate number of bars we will be able to display
        var numberOfBarsToCreate = Int(bounds.width/(barWidth + barSpacing))
        
        // Helper function for creating bars
        func createBar(_ positionFromCenter: Int) {
            let bar = UIView(frame: frame(forBar: positionFromCenter))
            bar.backgroundColor = barColor
            bar.layer.cornerRadius = (barCornerRadius < 0 || barCornerRadius > barWidth/2) ? floor(barWidth/3) : barCornerRadius
            
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
        let maxCount = (bars.count + 1)/2
        /*
         Note that the amount of bars will always be either 0, or an odd number (since the bars are counted in pairs after the first central bar), so we chose a "transformation" (a mathematical function) that satisfies this: value index = floor((bar index + 1)/2)
         
         Bar index:          0 1 2 3 4 5 6 7 8 9 ...
          (valid bar index): 0 1 - 3 - 5 - 7 - 9 ...
         Value index:        0 1 1 2 2 3 3 4 4 5 ...
         
         */
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
            // Note that total value may never reach 0, but this is small enough to clear everything out
            decayTimer?.invalidate()
            decayTimer = nil
        }
    }
    
    // MARK: - Public Methods
    
    /// Add a value to the visualizer. Be sure to call `AVAudioPlayer.isMeteringEnabled = true`, and `AVAudioPlayer.updateMeters()` before every call to `AVAudioPlayer.averagePower(forChannel: 0)`
    /// - Parameter decibelValue: The value you would get out of `AVAudioPlayer.averagePower(forChannel: 0)`
    public func addValue(decibelValue: Float) {
        addValue(decibelValue: Double(decibelValue))
    }
    
    /// Add a value to the visualizer. Be sure to call `AVAudioPlayer.isMeteringEnabled = true`, and `AVAudioPlayer.updateMeters()` before every call to `AVAudioPlayer.averagePower(forChannel: 0)`
    /// - Parameter decibelValue: The value you would get out of `AVAudioPlayer.averagePower(forChannel: 0)`
    public func addValue(decibelValue: Double) {
        let normalizedValue = __exp10(decibelValue/20)
        
        newestValue = normalizedValue
        
        startTimer()
    }

}
