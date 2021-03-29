//
//  NTPClientCongfig.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/3/28.
//

import Foundation

struct NTPClientConfig {
    /// the period to automatic sync time from NTP server
    let autoSyncTimePeriod: TimeInterval
    /// retry until success when sync time fail
    let isAutoRetryEnable: Bool
}
