//
//  ViewController.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/1/24.
//

import UIKit
import System

class ViewController: UIViewController {
    
    @IBOutlet private var label: UILabel!
    @IBOutlet private var button: UIButton!
    
    private let client = NTPClient()
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        client.listenNewCorrectedTime { [weak self] time in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.label.text = time.timeString
            }
        }
    }
}

extension ViewController {
    
    @IBAction private func retry() {
//        TimeAPI().getTime()
        client.send()
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(self.updateDisplayTime),
            userInfo: nil,
            repeats: true
        )
        self.timer?.fire()
        
        let boottimeInterval = getCurrentBoottime()
        let boottimeString = convert(boottimeInterval)
        
        let currentTimeInterval = getCurrentTime()
        let currentTimeString = convert(currentTimeInterval)
        
        print(boottimeString)
        print(currentTimeString)
    }
}

extension ViewController {
    
    private func convert(_ interval: TimeInterval) -> String {
        return convert(.init(timeIntervalSince1970: interval))
    }
    
    private func convert(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
    
    @objc
    private func updateDisplayTime() {
        guard let time = client.getTime() else { return }
        DispatchQueue.main.async {
            self.label.text = self.convert(time)
        }
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
