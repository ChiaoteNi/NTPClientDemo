//
//  NTPClock.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/3/19.
//

import Foundation

public final class NTPClock {
    
    typealias FetchTimeCallBack = (Date) -> Void
    
    private static var shared: NTPClock = .init()
    
    private var ntpClient: NTPClient = .init()
    private var config: NTPClientConfig
    private var currentTimer: Timer?
    
    private var currentCallBack: FetchTimeCallBack?
    private var correctedTime: CorrectedTime?
    
    static var currentTime: Date? {
        shared.fetchTimeAndSyncIfNeeded()?.currentTime
    }
    
    init() {
        config = .init(
            autoSyncTimePeriod: 30 * 60,
            isAutoRetryEnable: true
        )
        ntpClient.listenNewCorrectedTime { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let correctedTime):
                self.correctedTime = correctedTime
                self.ntpClient.close()
                
                guard let currentCallBack = self.currentCallBack else { return }
                currentCallBack(correctedTime.currentTime)
                self.correctedTime = nil
            case .failure(let error):
                print(error)
                if self.config.isAutoRetryEnable {
                    self.ntpClient.send()
                } else {
                    self.ntpClient.close()
                }
            }
        }
    }
    
    static func configuration(_ config: NTPClientConfig) {
        shared.config = config
        guard shared.currentTimer != nil else { return } // reset timer if timer already exist
        shared.createTimer()
    }
    
    static func start(then handler: FetchTimeCallBack? = nil) {
        shared.currentCallBack = handler
        shared.syncTime()
        
        guard shared.currentTimer == nil else { return }
        shared.createTimer()
    }
    
    static func forceUpdateTime(then handler: @escaping FetchTimeCallBack) {
        shared.currentCallBack = handler
        shared.syncTime()
    }
    
    static func listenTimeCorrectEvent(then handler: @escaping FetchTimeCallBack) {
        shared.ntpClient.listenNewCorrectedTime { result in
            switch result {
            case .success(let correctedTime):
                shared.correctedTime = correctedTime
                handler(correctedTime.currentTime)
            case .failure(let error):
                print(error)
            }
        }
    }
}

extension NTPClock {
    
    private func syncTime() {
        ntpClient.start()
        ntpClient.send()
    }
    
    private func fetchTimeAndSyncIfNeeded() -> CorrectedTime? {
        if let correctedTime = correctedTime {
            return correctedTime
        } else {
            ntpClient.send()
            return nil
        }
    }
    
    private func createTimer() {
        clearTimer()
        let timer: Timer = .scheduledTimer(
            withTimeInterval: config.autoSyncTimePeriod,
            repeats: true
        ) { [weak self] timer in
            self?.syncTime()
        }
        RunLoop.current.add(timer, forMode: .common)
        timer.fire()
        currentTimer = timer
    }
    
    private func clearTimer() {
        currentTimer?.invalidate()
        currentTimer = nil
    }
    
}
