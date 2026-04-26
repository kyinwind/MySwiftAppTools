import Foundation
import OSLog

public enum LogLevel {
    case debug, info, warn, error
}

public struct Log {
    nonisolated(unsafe) public static var isEnabled: Bool = true

    nonisolated(unsafe) private static var subsystem = Bundle.main.bundleIdentifier ?? "MySwiftAppTools"
    nonisolated(unsafe) private static var loggers: [String: Logger] = [:]

    public static func configure(
        subsystem: String? = nil,
        isEnabled: Bool = true
    ) {
        self.subsystem = subsystem ?? Bundle.main.bundleIdentifier ?? "MySwiftAppTools"
        self.isEnabled = isEnabled
        loggers.removeAll()
    }

    public static func logger(category: String) -> Logger {
        if let logger = loggers[category] {
            return logger
        }
        let newLogger = Logger(subsystem: subsystem, category: category)
        loggers[category] = newLogger
        return newLogger
    }

    public static func log(
        _ category: String = "General",
        _ level: LogLevel,
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ){
        // Release 只保留 error
        #if !DEBUG
        if level != .error { return }
        #endif

        guard isEnabled else { return }

        let logger = logger(category: category)
        let filename = (file as NSString).lastPathComponent
        let msg = "\(filename):\(line) \(function) -> \(message())"

        switch level {
        case .debug:
            logger.debug("\(msg, privacy: .private)")
        case .info:
            logger.info("\(msg, privacy: .private)")
        case .warn:
            logger.notice("\(msg, privacy: .private)")
        case .error:
            logger.error("\(msg, privacy: .public)")
        }
        
    }
    // MARK: - Shortcut APIs

    public static func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .debug, message(), file: file, function: function, line: line)
    }

    public static func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .info, message(), file: file, function: function, line: line)
    }

    public static func warn(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .warn, message(), file: file, function: function, line: line)
    }

    public static func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .error, message(), file: file, function: function, line: line)
    }
}
