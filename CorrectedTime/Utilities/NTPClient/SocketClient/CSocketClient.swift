//
//  CSocketClient.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/3/13.
//

import Foundation

final class CSocketClient {
    
    typealias ReceiveHandler = (_ data: Data) -> Void
    
    private var socket: CFSocket?
    private var currentAddressData: CFData?
    private var ips: [String]
    private var currentSource: CFRunLoopSource?
    
    private var receiveHandlers: [ReceiveHandler] = []
    private let receiveQueue: DispatchQueue = .init(
        label: "time.apple.com.NTPQueue",
        qos: .background,
        autoreleaseFrequency: .never
    )
    
    private var preparePacket: (()->Data)?
    
    private let callback: CFSocketCallBack = { socket, callbackType, address, data, info in
        guard let info = info else { return }
        let socketClient = Unmanaged<CSocketClient>
            .fromOpaque(info)
            .takeUnretainedValue()
        
        guard callbackType != .writeCallBack else {
            if let packet = socketClient.preparePacket?(),
               let ip = socketClient.ips.first {
                let ipData = socketClient.getAddressData(address: ip)
                CFSocketSendData(socketClient.socket, ipData, packet as CFData, 6.0)
            }
            return
        }
        
        guard let data = unsafeBitCast(data, to: CFData.self) as Data? else { return }
        socketClient.receiveQueue.async {
            socketClient.receiveHandlers.forEach { callBack in
                callBack(data)
            }
        }
    }
    
    init(host: String = "time.apple.com") {
        ips = getServerAddress(host: host)
    }
    
    func start() {
        guard let ip = ips.first else {
            return assert(false)
        }
        guard socket == nil, currentSource == nil else { return }
        
        let info = UnsafeMutableRawPointer(
            Unmanaged<CSocketClient>
                .passUnretained(self)
                .toOpaque()
        )
        var ctx = CFSocketContext(
            version: 0,
            info: info,
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let types = CFSocketCallBackType.dataCallBack.rawValue |
            CFSocketCallBackType.writeCallBack.rawValue
        
        self.socket = CFSocketCreate(
            nil,
            PF_INET,
            SOCK_DGRAM,
            IPPROTO_UDP,
            types,
            callback,
            &ctx
        )
        
        let runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            runLoopSource,
            .commonModes
        )
        self.currentSource = runLoopSource
        
        let ipData = getAddressData(address: ip)
        CFSocketConnectToAddress(socket, ipData, 6.0)
    }
    
    func listen(then handler: @escaping ReceiveHandler) {
        receiveHandlers.append(handler)
    }
    
    func close() {
        if let source = currentSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        }
        if let socket = socket {
            CFSocketInvalidate(socket)
        }
        socket = nil
        currentSource = nil
    }
    
    func send(packet: @escaping () -> Data) {
        if let socket = socket {
            CFSocketSendData(socket, nil, packet() as CFData, 0.6)
        } else {
            preparePacket = packet
        }
    }
}

// MARK: - Private functions
extension CSocketClient {
    
    private func getAddressData(address: String) -> CFData {
        /*
         (1) sockaddr：Unix 作業系統格式（AF_UNIX）。
         (2) sockaddr_in：Internet 網路格式（AF_INET）。
         (3) sockaddr_un：本機迴授位址（Loopback）格式（AF_UNIX）
         */
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET) // address family, ipv4 or ipv6
        // inet_addr: function converts the Internet host address cp from IPv4 numbers-and-dots notation into binary data in network byte order.
        addr.sin_addr.s_addr = inet_addr(address) // address
        addr.sin_port = in_port_t(123).bigEndian
        return Data(bytes: &addr, count: MemoryLayout<sockaddr_in>.size) as CFData
    }
}

fileprivate
func getServerAddress(host: String = "time.apple.com") -> [String] {
    var timeservers: [String] = []
    
    let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
    CFHostStartInfoResolution(host, .addresses, nil)
    
    var success: DarwinBoolean = false
    guard let addresses = CFHostGetAddressing(host, &success)?
            .takeUnretainedValue() as NSArray? else { return timeservers }
    
    for case let address as Data in addresses {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        /*
         int getnameinfo(const struct sockaddr *sa, socklen_t salen,
                         char *host, size_t hostlen,
                         char *serv, size_t servlen, int flags);
         flags - NI_NOFQDN 會讓 host 只包含 host name，而不是全部的 domain name（網域名稱)
         如果在 DNS 查詢時無法找到 name 的時候，NI_NAMEREQD 會讓函式發生失敗
         如果你沒有指定這個 flag，而又無法找到 name 時，那 getnameinfo() 就會改為將一個字串版本的 IP address 放在 host 裡面
         */
        let socketAddress = address
            .withUnsafeBytes({ UnsafeRawPointer($0) })
            .assumingMemoryBound(to: sockaddr.self)
        
        let result = getnameinfo(
            socketAddress,
            socklen_t(address.count),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST // Return the numeric form of the host's address
        )
        /*
         NI_NOFQDN
            Return only the nodename portion of the FQDN for local hosts.
         NI_NUMERICHOST
            Return the numeric form of the host's address (i.e., by calling inet_ntop() instead of gethostbyaddr()).
         NI_NAMEREQD
            Indicate an error if the host's name can't be located in the DNS.
         NI_NUMERICSERV
            Return the numeric form of the service address (i.e., its port number) instead of its name.
         NI_DGRAM
            Specify that the service is a datagram service. This flag makes the function call getservbyport() with a second argument of udp instead of tcp. This is required for the few ports (512-514) that have different services for UDP and TCP.
         */
        
        guard result == 0 else { continue }
        let numAddress = String(cString: hostname)
        /*
         (1) sockaddr：Unix 作業系統格式（AF_UNIX）。
         (2) sockaddr_in：Internet 網路格式（AF_INET）。
         (3) sockaddr_un：本機迴授位址（Loopback）格式（AF_UNIX）
         */
        var sin = sockaddr_in()
        if numAddress.withCString({ cstring in
            /*
             int inet_pton(int family, const char *strptr, void *addrptr)
             family: AF_INET（ipv4）|| AF_INET6（ipv6）
             
             將字串格式的 IP address 封裝到 struct sockaddr_in 或 struct sockaddr_in6
             若成功則為1,若輸入不是有效的表達格式則為0,若出錯則為-1
             */
            inet_pton(AF_INET, cstring, &sin.sin_addr)
        }) == 1 {
            //It's an ipv4 address
            timeservers.append(numAddress)
        }
    }
    return timeservers
}
