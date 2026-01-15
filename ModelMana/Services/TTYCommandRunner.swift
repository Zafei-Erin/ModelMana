//
//  TTYCommandRunner.swift
//  ModelMana
//
//  Generic PTY runner for interactive CLI commands
//

import Foundation

// MARK: - ShellPathLocator

/// Helper to locate binaries using the user's login shell PATH
enum ShellPathLocator {
    /// Cached login shell PATH (captured once)
    private static var cachedPATH: String?

    /// Capture the user's login shell PATH
    /// This runs the user's shell with -l -i flags to load .zshrc/.bashrc etc.
    static func capturePATH() -> String {
        if let cached = cachedPATH { return cached }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        // -l = login shell (reads .zshrc/.bashrc), -i = interactive
        // This picks up PATH modifications from nvm/fnm/mise
        process.arguments = ["-l", "-i", "-c", "echo \"$PATH\""]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !path.isEmpty {
                cachedPATH = path
                return path
            }
        } catch {
            // Silent failure, use fallback
        }

        // Fallback to system PATH
        let fallback = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        cachedPATH = fallback
        return fallback
    }

    /// Find a binary using the captured login shell PATH
    static func which(_ tool: String) -> String? {
        let path = capturePATH()
        let directories = path.split(separator: ":").map(String.init)

        for dir in directories where !dir.isEmpty {
            let candidate = dir.hasSuffix("/") ? "\(dir)\(tool)" : "\(dir)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }
}
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// PTY command runner result
public struct TTYCommandResult {
    public let text: String
    public let success: Bool
    public let error: String?

    public init(text: String, success: Bool, error: String? = nil) {
        self.text = text
        self.success = success
        self.error = error
    }
}

/// PTY command runner options
public struct TTYCommandOptions {
    public var rows: UInt16 = 50
    public var cols: UInt16 = 160
    public var timeout: TimeInterval = 120
    public var extraArgs: [String] = []
    public var initialDelay: TimeInterval = 0.4
    public var settleAfterStop: TimeInterval = 0.25
    public var stopOnSubstrings: [String] = []
    public var sendOnSubstrings: [String: String] = [:]

    public init(
        rows: UInt16 = 50,
        cols: UInt16 = 160,
        timeout: TimeInterval = 120,
        extraArgs: [String] = [],
        initialDelay: TimeInterval = 0.4,
        settleAfterStop: TimeInterval = 0.25,
        stopOnSubstrings: [String] = [],
        sendOnSubstrings: [String: String] = [:]
    ) {
        self.rows = rows
        self.cols = cols
        self.timeout = timeout
        self.extraArgs = extraArgs
        self.initialDelay = initialDelay
        self.settleAfterStop = settleAfterStop
        self.stopOnSubstrings = stopOnSubstrings
        self.sendOnSubstrings = sendOnSubstrings
    }
}

/// PTY command errors
public enum TTYCommandError: LocalizedError {
    case binaryNotFound(String)
    case launchFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let bin):
            return "CLI '\(bin)' not found. Please install it first."
        case .launchFailed(let msg):
            return "Failed to launch process: \(msg)"
        case .timedOut:
            return "Command timed out."
        }
    }
}

/// Generic PTY command runner
public struct TTYCommandRunner {

    // MARK: - Result

    public struct Result {
        public let text: String
    }

    // MARK: - Options

    public struct Options {
        public var rows: UInt16 = 50
        public var cols: UInt16 = 160
        public var timeout: TimeInterval = 120
        public var extraArgs: [String] = []
        public var initialDelay: TimeInterval = 0.4
        public var settleAfterStop: TimeInterval = 0.25
        public var stopOnSubstrings: [String] = []
        public var sendOnSubstrings: [String: String] = [:]

        // For each pattern, how long to wait after sending before checking next patterns
        public var sendDelays: [String: TimeInterval] = [:]

        public init(
            rows: UInt16 = 50,
            cols: UInt16 = 160,
            timeout: TimeInterval = 120,
            extraArgs: [String] = [],
            initialDelay: TimeInterval = 0.4,
            settleAfterStop: TimeInterval = 0.25,
            stopOnSubstrings: [String] = [],
            sendOnSubstrings: [String: String] = [:],
            sendDelays: [String: TimeInterval] = [:]
        ) {
            self.rows = rows
            self.cols = cols
            self.timeout = timeout
            self.extraArgs = extraArgs
            self.initialDelay = initialDelay
            self.settleAfterStop = settleAfterStop
            self.stopOnSubstrings = stopOnSubstrings
            self.sendOnSubstrings = sendOnSubstrings
            self.sendDelays = sendDelays
        }
    }

    // MARK: - Errors

    public enum Error: Swift.Error, LocalizedError {
        case binaryNotFound(String)
        case launchFailed(String)
        case timedOut

        public var errorDescription: String? {
            switch self {
            case .binaryNotFound(let bin):
                return "Missing CLI '\(bin)'. Install it or add to PATH."
            case .launchFailed(let msg):
                return "Failed to launch: \(msg)"
            case .timedOut:
                return "Command timed out."
            }
        }
    }

    // MARK: - Rolling Buffer

    struct RollingBuffer {
        private let maxNeedle: Int
        private var tail = Data()

        init(maxNeedle: Int) {
            self.maxNeedle = max(0, maxNeedle)
        }

        mutating func append(_ data: Data) -> Data {
            guard !data.isEmpty else { return Data() }

            var combined = Data()
            combined.reserveCapacity(tail.count + data.count)
            combined.append(tail)
            combined.append(data)

            if maxNeedle > 1 {
                if combined.count >= maxNeedle - 1 {
                    tail = combined.suffix(maxNeedle - 1)
                } else {
                    tail = combined
                }
            } else {
                tail.removeAll(keepingCapacity: true)
            }

            return combined
        }

        mutating func reset() {
            tail.removeAll(keepingCapacity: true)
        }
    }

    // MARK: - Run

    public init() {}

    /// Run a command in a PTY
    /// - Parameters:
    ///   - binary: Command name or path
    ///   - send: Initial input to send (empty string for none)
    ///   - options: Configuration options
    ///   - onURLDetected: Callback when a URL is detected in output
    /// - Returns: Result containing captured output
    public func run(
        binary: String,
        send script: String,
        options: Options = Options(),
        onURLDetected: (@Sendable () -> Void)? = nil
    ) throws -> Result
    {
        // Resolve binary path
        let resolved: String
        if FileManager.default.isExecutableFile(atPath: binary) {
            resolved = binary
        } else if let hit = Self.which(binary) {
            resolved = hit
        } else {
            throw Error.binaryNotFound(binary)
        }

        // Create PTY
        var primaryFD: Int32 = -1
        var secondaryFD: Int32 = -1
        var win = winsize(ws_row: options.rows, ws_col: options.cols, ws_xpixel: 0, ws_ypixel: 0)

        guard openpty(&primaryFD, &secondaryFD, nil, nil, &win) == 0 else {
            throw Error.launchFailed("openpty failed: \(String(cString: strerror(errno)))")
        }

        // Make primary non-blocking
        _ = fcntl(primaryFD, F_SETFL, O_NONBLOCK)

        let primaryHandle = FileHandle(fileDescriptor: primaryFD, closeOnDealloc: true)
        let secondaryHandle = FileHandle(fileDescriptor: secondaryFD, closeOnDealloc: true)

        // Cleanup handler
        var cleanedUp = false
        var didLaunch = false
        var processGroup: pid_t?

        func cleanup() {
            guard !cleanedUp else { return }
            cleanedUp = true

            try? primaryHandle.close()
            try? secondaryHandle.close()

            guard didLaunch else { return }

            let proc = Process()
            if proc.isRunning {
                proc.terminate()
            }
            if let pgid = processGroup {
                kill(-pgid, SIGTERM)
            }
            let waitDeadline = Date().addingTimeInterval(2.0)
            while proc.isRunning, Date() < waitDeadline {
                usleep(100_000)
            }
            if proc.isRunning {
                if let pgid = processGroup {
                    kill(-pgid, SIGKILL)
                }
                kill(proc.processIdentifier, SIGKILL)
            }
        }

        defer { cleanup() }

        // Configure process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: resolved)
        proc.arguments = options.extraArgs
        proc.standardInput = secondaryHandle
        proc.standardOutput = secondaryHandle
        proc.standardError = secondaryHandle

        // Set environment
        var env = ProcessInfo.processInfo.environment
        if env["PATH"]?.isEmpty ?? true {
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
        }
        if env["TERM"]?.isEmpty ?? true {
            env["TERM"] = "xterm-256color"
        }
        if env["HOME"]?.isEmpty ?? true {
            env["HOME"] = NSHomeDirectory()
        }
        proc.environment = env

        // Start process
        try proc.run()
        didLaunch = true

        // Create process group
        let pid = proc.processIdentifier
        if setpgid(pid, pid) == 0 {
            processGroup = pid
        }

        // Write function
        func writeAll(_ data: Data) throws {
            try data.withUnsafeBytes { rawBytes in
                guard let baseAddress = rawBytes.baseAddress else { return }
                var offset = 0
                var retries = 0
                while offset < rawBytes.count {
                    let written = write(primaryFD, baseAddress.advanced(by: offset), rawBytes.count - offset)
                    if written > 0 {
                        offset += written
                        retries = 0
                        continue
                    }
                    if written == 0 { break }

                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        retries += 1
                        if retries > 200 {
                            throw Error.launchFailed("write would block")
                        }
                        usleep(5000)
                        continue
                    }
                    throw Error.launchFailed("write failed: \(String(cString: strerror(err)))")
                }
            }
        }

        func send(_ text: String) throws {
            guard let data = text.data(using: .utf8) else { return }
            try writeAll(data)
        }

        // Read loop
        let deadline = Date().addingTimeInterval(options.timeout)
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)

        var buffer = Data()
        func readChunk() -> Data {
            var appended = Data()
            while true {
                var tmp = [UInt8](repeating: 0, count: 8192)
                let n = read(primaryFD, &tmp, tmp.count)
                if n > 0 {
                    let slice = tmp.prefix(n)
                    buffer.append(contentsOf: slice)
                    appended.append(contentsOf: slice)
                    continue
                }
                break
            }
            return appended
        }

        // Prepare needles
        let stopNeedles = options.stopOnSubstrings.map { Data($0.utf8) }
        // Sort keys in reverse to ensure consistent order - we want longer/more specific patterns first
        let sendNeedles = options.sendOnSubstrings.sorted { $0.key > $1.key }.map {
            (needle: Data($0.key.utf8), response: Data($0.value.utf8))
        }
        let urlNeedles = [Data("https://".utf8), Data("http://".utf8)]
        let needleLengths =
            stopNeedles.map(\.count) +
            sendNeedles.map(\.needle.count) +
            urlNeedles.map(\.count)
        let maxNeedle = needleLengths.max() ?? 0

        var scanBuffer = RollingBuffer(maxNeedle: maxNeedle)
        var stoppedEarly = false
        var triggeredSends = Set<Data>()
        var recentText = ""

        usleep(UInt32(options.initialDelay * 1_000_000))

        // Send initial script
        if !trimmed.isEmpty {
            try send(trimmed)
            try send("\r")
        }

        // Main read loop
        while Date() < deadline {
            let newData = readChunk()
            if !newData.isEmpty, let chunkText = String(bytes: newData, encoding: .utf8) {
                recentText += chunkText
                if recentText.count > 8192 {
                    recentText.removeFirst(recentText.count - 8192)
                }
            }

            let scanData = scanBuffer.append(newData)

            // Check for send patterns
            for item in sendNeedles where !triggeredSends.contains(item.needle) {
                let needleString = String(data: item.needle, encoding: .utf8) ?? ""
                let matched = scanData.range(of: item.needle) != nil ||
                    recentText.contains(needleString)
                if matched {
                    let responseDesc = String(data: item.response, encoding: .utf8)?.debugDescription ?? "?"
                    print("[TTYCommandRunner] Matched '\(needleString)', sending: \(responseDesc)")
                    try? writeAll(item.response)
                    triggeredSends.insert(item.needle)

                    // Check if there's a delay configured for this pattern
                    if let delay = options.sendDelays[needleString], delay > 0 {
                        print("[TTYCommandRunner] Waiting \(delay)s after sending '\(needleString)'")
                        usleep(UInt32(delay * 1_000_000))
                    }
                }
            }

            // Check for URL
            if urlNeedles.contains(where: { scanData.range(of: $0) != nil }) {
                onURLDetected?()
            }

            // Check for stop patterns
            if !stopNeedles.isEmpty, stopNeedles.contains(where: { scanData.range(of: $0) != nil }) {
                stoppedEarly = true
                break
            }

            if !proc.isRunning { break }
            usleep(60000) // 60ms poll
        }

        // Settle period after stop
        if stoppedEarly {
            let settle = max(0, min(options.settleAfterStop, deadline.timeIntervalSinceNow))
            if settle > 0 {
                let settleDeadline = Date().addingTimeInterval(settle)
                while Date() < settleDeadline {
                    let newData = readChunk()
                    _ = scanBuffer.append(newData)
                    usleep(50000)
                }
            }
        }

        let text = String(data: buffer, encoding: .utf8) ?? ""
        return Result(text: text)
    }

    // MARK: - Helpers

    /// Find binary in PATH (delegates to ShellPathLocator)
    public static func which(_ tool: String) -> String? {
        return ShellPathLocator.which(tool)
    }
}
