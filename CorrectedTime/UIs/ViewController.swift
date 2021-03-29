//
//  ViewController.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/1/24.
//

import UIKit
import System
//import TrueTime

class ViewController: UIViewController {
    
    @IBOutlet private var label: UILabel!
    @IBOutlet private var button: UIButton!
    
//    private let client = NTPClient()
    
    private let clock = NTPClock()
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        NTPClock.configuration(
            .init(
                autoSyncTimePeriod: 3,
                isAutoRetryEnable: true
            )
        )
        NTPClock.listenTimeCorrectEvent { date in
            self.updateDisplayTime()
        }
        NTPClock.start { [weak self] _ in
            self?.updateDisplayTime()
        }
    }
}

extension ViewController {
    
    @IBAction private func retry() {
//        TimeAPI().getTime()
//        self.timer?.invalidate()
//        self.timer = Timer.scheduledTimer(
//            timeInterval: 1,
//            target: self,
//            selector: #selector(self.updateDisplayTime),
//            userInfo: nil,
//            repeats: true
//        )
//        self.timer?.fire()
        updateDisplayTime()
    }
}

extension ViewController {
    
    @objc
    private func updateDisplayTime() {
        guard let time = NTPClock.currentTime else { return }
        DispatchQueue.main.async {
            self.label.text = self.convert(time)
        }
    }
    
    private func convert(_ interval: TimeInterval) -> String {
        return convert(.init(timeIntervalSince1970: interval))
    }
    
    private func convert(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

private func getCurrentBoottime() -> TimeInterval {
    var mib = [CTL_KERN, KERN_BOOTTIME]
    var bootTime = timeval()
    var size = MemoryLayout<timeval>.stride
    
    let error = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0)
    if error != 0 {
        assertionFailure("Get boot time fail, error: \(error)")
    }
    return Double(bootTime.tv_sec) + (Double(bootTime.tv_usec) / 1000000)
}

private func getCurrentTime() -> TimeInterval {
    var current = timeval()
    
    let error = gettimeofday(&current, nil)
    if error != 0 {
        assertionFailure("system clock error: system time unavailable \(error)")
    }
    return Double(current.tv_sec) + (Double(current.tv_usec) / 1000000)
}
