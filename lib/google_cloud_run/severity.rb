class Logger
  module Severity
    # Ruby/Rails default severities:
    # Low-level information, mostly for developers.
    # DEBUG = 0
    # Generic (useful) information about system operation.
    # INFO = 1
    # A warning.
    # WARN = 2
    # A handleable error condition.
    # ERROR = 3
    # An unhandleable error that results in a program crash.
    # FATAL = 4
    # An unknown message that should always be logged.
    # UNKNOWN = 5

    # Google Cloud severities:
    # The log entry has no assigned severity level.
    G_DEFAULT = 0

    # Debug or trace information.
    G_DEBUG = 100

    # Routine information, such as ongoing status or performance.
    G_INFO = 200

    # Normal but significant events, such as start up, shut down, or a configuration change.
    G_NOTICE = 300

    # Warning events might cause problems.
    G_WARNING = 400

    # Error events are likely to cause problems.
    G_ERROR = 500

    # Critical events cause more severe problems or outages.
    G_CRITICAL = 600

    # A person must take an action immediately.
    G_ALERT = 700

    # One or more systems are unusable.
    G_EMERGENCY = 800
  end
end

module GoogleCloudRun
  module Severity
    include ::Logger::Severity

    def self.to_s(severity)
      case mapping(severity)
      when G_DEFAULT; return "DEFAULT"
      when G_DEBUG; return "DEBUG"
      when G_INFO; return "INFO"
      when G_NOTICE; return "NOTICE"
      when G_WARNING; return "WARNING"
      when G_ERROR; return "ERROR"
      when G_CRITICAL; return "CRITICAL"
      when G_ALERT; return "ALERT"
      when G_EMERGENCY; return "EMERGENCY"
      end
    end

    def self.mapping(severity)
      case severity
      when nil; return G_DEFAULT
      when G_DEFAULT, G_DEBUG, G_INFO, G_NOTICE, G_WARNING, G_ERROR, G_CRITICAL, G_ALERT, G_EMERGENCY; return severity
      when DEBUG; return G_DEBUG
      when INFO; return G_INFO
      when WARN; return G_WARNING
      when ERROR; return G_ERROR
      when FATAL; return G_CRITICAL
      when UNKNOWN; return G_DEFAULT
      when 0; return G_DEFAULT
      when 1; return G_INFO
      when 2; return G_WARNING
      when 3; return G_ERROR
      when 4; return G_CRITICAL
      when 5; return G_DEFAULT
      when 100; return G_DEBUG
      when 200; return G_INFO
      when 300; return G_NOTICE
      when 400; return G_WARNING
      when 500; return G_ERROR
      when 600; return G_CRITICAL
      when 700; return G_ALERT
      when 800; return G_EMERGENCY
      when "G_DEFAULT"; return G_DEFAULT
      when "G_DEBUG"; return G_DEBUG
      when "G_INFO"; return G_INFO
      when "G_NOTICE"; return G_NOTICE
      when "G_WARNING"; return G_WARNING
      when "G_ERROR"; return G_ERROR
      when "G_CRITICAL"; return G_CRITICAL
      when "G_ALERT"; return G_ALERT
      when "G_EMERGENCY"; return G_EMERGENCY
      when :g_default; return G_DEFAULT
      when :g_debug; return G_DEBUG
      when :g_info; return G_INFO
      when :g_notice; return G_NOTICE
      when :g_warning; return G_WARNING
      when :g_error; return G_ERROR
      when :g_critical; return G_CRITICAL
      when :g_alert; return G_ALERT
      when :g_emergency; return G_EMERGENCY
      when :debug; return G_DEBUG
      when :info; return G_INFO
      when :warn; return G_WARNING
      when :error; return G_ERROR
      when :fatal; return G_CRITICAL
      when :unknown; return G_DEFAULT
      when :default; return G_DEFAULT
      when :notice; return G_NOTICE
      when :warning; return G_WARNING
      when :critical; return G_CRITICAL
      when :alert; return G_ALERT
      when :emergency; return G_EMERGENCY
      else
        raise "unknown severity '#{severity.inspect}'"
      end
    end
  end
end
