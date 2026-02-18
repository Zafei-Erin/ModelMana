//
//  ShellPathLocator.swift
//  ModelMana
//
//  Helper to locate binaries using the user's login shell PATH
//

import Foundation

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
