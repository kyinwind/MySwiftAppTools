import OSLog

enum LogLevel {
    case debug, info, warn, error
}

struct Log {
    nonisolated(unsafe) static var isEnabled: Bool = true

    nonisolated(unsafe) private static var subsystem = "com.michaeldev"
    nonisolated(unsafe) private static var loggers: [String: Logger] = [:]

    static func logger(category: String) -> Logger {
        if let logger = loggers[category] {
            return logger
        }
        let newLogger = Logger(subsystem: subsystem, category: category)
        loggers[category] = newLogger
        return newLogger
    }

    static func log(
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

    static func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .debug, message(), file: file, function: function, line: line)
    }

    static func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .info, message(), file: file, function: function, line: line)
    }

    static func warn(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .warn, message(), file: file, function: function, line: line)
    }

    static func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("General", .error, message(), file: file, function: function, line: line)
    }
}
