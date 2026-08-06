import Foundation

enum ProcessRunnerError: LocalizedError {
    case executableMissing(String)
    case nonZeroExit(code: Int32, stderr: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .executableMissing(let name):
            return "Bundled tool missing: \(name)."
        case .nonZeroExit(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Process failed with exit code \(code)."
            }
            return trimmed
        case .cancelled:
            return "Cancelled."
        }
    }
}

struct ProcessOutput {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

actor ProcessRunner {
    private var current: Process?

    func cancel() {
        current?.terminate()
        current = nil
    }

    @discardableResult
    func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil,
        onStdoutLine: ((String) -> Void)? = nil,
        onStderrLine: ((String) -> Void)? = nil
    ) async throws -> ProcessOutput {
        try Task.checkCancellation()

        guard FileManager.default.fileExists(atPath: executable.path) else {
            throw ProcessRunnerError.executableMissing(executable.lastPathComponent)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        // Keep PATH locked to bundled Helpers so child tools never call Homebrew.
        let helpers = BinaryLocator.helpersDirectory.path
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = helpers
        env["YTDLP_NO_UPDATE"] = "1"
        if let environment {
            env.merge(environment) { _, new in new }
        }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        current = process

        let lock = NSLock()
        var stdoutData = Data()
        var stderrData = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock(); stdoutData.append(chunk); lock.unlock()
            if let onStdoutLine {
                Self.emitLines(from: chunk, into: onStdoutLine)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock(); stderrData.append(chunk); lock.unlock()
            if let onStderrLine {
                Self.emitLines(from: chunk, into: onStderrLine)
            }
        }

        do {
            try process.run()
        } catch {
            current = nil
            throw ProcessRunnerError.executableMissing(executable.lastPathComponent)
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        current = nil

        if Task.isCancelled {
            throw ProcessRunnerError.cancelled
        }

        lock.lock()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        lock.unlock()
        let code = process.terminationStatus

        if code != 0 {
            throw ProcessRunnerError.nonZeroExit(code: code, stderr: stderr.isEmpty ? stdout : stderr)
        }

        return ProcessOutput(stdout: stdout, stderr: stderr, exitCode: code)
    }

    private static func emitLines(from data: Data, into handler: (String) -> Void) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                handler(String(trimmed))
            }
        }
    }
}
