//
//  CorrectedTime.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/1/26.
//

import Foundation

struct CorrectedTime {
    
    let offset: TimeInterval
    let uptime: TimeInterval
    let boottime: TimeInterval
    
    var currentTime: Date { getCurrentTime() }
    
    var timeString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: currentTime)
    }
    
    init(offset: TimeInterval, originBoottime: TimeInterval) {
        self.offset = offset
        self.boottime = originBoottime
        self.uptime = CorrectedTime.currentTime() - CorrectedTime.getCurrentBoottime()
    }
    
    private func getCurrentTime() -> Date {
        let offset = (boottime - CorrectedTime.getCurrentBoottime()) + self.offset
        let currentTime = CorrectedTime.currentTime() + offset
        return Date.init(timeInterval: currentTime, since: .init(timeIntervalSince1970: 0))
    }
}

extension CorrectedTime {
    
    static func getCurrentBoottime() -> TimeInterval {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride
        
        let error = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0)
        if error != 0 {
            assertionFailure("Get boot time fail, error: \(error)")
        }
        return Double(bootTime.tv_sec) + (Double(bootTime.tv_usec) / 1000000)
    }

    static func currentTime() -> TimeInterval {
        var current = timeval()
        
        let error = gettimeofday(&current, nil)
        if error != 0 {
            assertionFailure("system clock error: system time unavailable \(error)")
        }
        return Double(current.tv_sec) + (Double(current.tv_usec) / 1000000)
    }
}
