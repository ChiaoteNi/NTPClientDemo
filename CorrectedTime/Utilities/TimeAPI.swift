//
//  TimeAPI.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/1/26.
//

import Foundation

final class TimeAPI {
    
    var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
    
    func getTime() {
        guard let url = URL(string: "https://www.chiaoni3145951.com/TimeApi.php") else { return }
        let request: URLRequest = .init(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 3
        )
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let dateString = (response as? HTTPURLResponse)?.allHeaderFields["Date"] as? String
            let date = self.convertTimeText(dateString)
//            print("=======\(date)")
        }
        task.resume()
    }
}

extension TimeAPI {
    
    private func convertTimeText(_ text: String?) -> Date? {
        guard let text = text else { return nil }
        return formatter.date(from: text)
    }
}
