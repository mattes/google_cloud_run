module GoogleCloudRun
  class Logger
    include ::Logger::Severity

    def initialize
      @level = G_INFO
      @formatter = DummyFormatter.new
      @out = Rails.application.config.google_cloudrun.out
      @project_id = GoogleCloudRun.project_id
    end

    def level=(level)
      @level = Severity.mapping(level)
    end

    def level?(level)
      Severity.mapping(level) >= @level
    end

    def log(severity, msg = nil, progname = nil, **labels, &block)
      labels["progname"] = progname unless progname.blank?
      write(severity, msg, labels, &block)
    end

    def default(msg = nil, **labels, &block)
      write(G_DEFAULT, msg, labels, &block)
    end

    def default?
      self.level?(G_DEFAULT)
    end

    def default!
      self.level = G_DEFAULT
    end

    def debug(msg = nil, **labels, &block)
      write(G_DEBUG, msg, labels, &block)
    end

    def debug?
      self.level?(G_DEBUG)
    end

    def debug!
      self.level = G_DEBUG
    end

    def info(msg = nil, **labels, &block)
      write(G_INFO, msg, labels, &block)
    end

    def info?
      self.level?(G_INFO)
    end

    def info!
      self.level = G_INFO
    end

    def notice(msg = nil, **labels, &block)
      write(G_NOTICE, msg, labels, &block)
    end

    def notice?
      self.level?(G_NOTICE)
    end

    def notice!
      self.level = G_NOTICE
    end

    def warning(msg = nil, **labels, &block)
      write(G_WARNING, msg, labels, &block)
    end

    def warning?
      self.level?(G_WARNING)
    end

    def warning!
      self.level = G_WARNING
    end

    def error(msg = nil, **labels, &block)
      write(G_ERROR, msg, labels, &block)
    end

    def error?
      self.level?(G_ERROR)
    end

    def error!
      self.level = G_ERROR
    end

    def critical(msg = nil, **labels, &block)
      write(G_CRITICAL, msg, labels, &block)
    end

    def critical?
      self.level?(G_CRITICAL)
    end

    def critical!
      self.level = G_CRITICAL
    end

    def alert(msg = nil, **labels, &block)
      write(G_ALERT, msg, labels, &block)
    end

    def alert?
      self.level?(G_ALERT)
    end

    def alert!
      self.level = G_ALERT
    end

    def emergency(msg = nil, **labels, &block)
      write(G_EMERGENCY, msg, labels, &block)
    end

    def emergency?
      self.level?(G_EMERGENCY)
    end

    def emergency!
      self.level = G_EMERGENCY
    end

    def <<(msg)
      log(G_DEBUG, msg)
    end

    # called by LoggerMiddleware
    def inject_request(request)
      Thread.current[thread_key] = request
    end

    # called by ActiveSupport::LogSubscriber.flush_all!
    def flush
      Thread.current[thread_key] = nil
      @out.flush
    end

    def datetime_format
      "%FT%T.%9NZ" # RFC3339 UTC "Zulu" format, with nanosecond resolution and up to nine fractional digits
    end

    def formatter
      @formatter
    end

    # implement ::Logger interface, but do nothing
    def close; end

    def reopen(logdev = nil); end

    def datetime_format=(format); end

    def formatter=(formatter); end

    alias_method :warn, :warning
    alias_method :warn!, :warning!
    alias_method :warn?, :warning?
    alias_method :unknown, :default
    alias_method :fatal, :critical
    alias_method :fatal!, :critical!
    alias_method :fatal?, :critical?
    alias_method :add, :log
    alias_method :sev_threshold, :level=

    private

    def should_log?(severity)
      Rails.application.config.google_cloudrun.logger && self.level?(severity)
    end

    def should_error_report?(severity)
      Rails.application.config.google_cloudrun.error_reporting &&
        !Rails.application.config.google_cloudrun.error_reporting_level.nil? &&
        Severity.mapping(severity) >= Severity.mapping(Rails.application.config.google_cloudrun.error_reporting_level)
    end

    def write(severity, msg, labels = {}, &block)
      should_log = should_log?(severity)
      should_error_report = should_error_report?(severity)
      return false if !should_log && !should_error_report

      # execute given block
      msg = block.call if block

      # write error report
      if should_error_report
        write_error_report(severity, msg, labels)

        # return early if we don't want to log as well
        return true if Rails.application.config.google_cloudrun.error_reporting_discard_log
      end

      # write log
      if should_log
        write_log(severity, msg, labels)
      end

      return true
    end

    def write_log(severity, msg, labels)
      l = GoogleCloudRun::LogEntry.new
      l.severity = severity
      l.message = msg
      l.labels = labels
      l.request = current_request
      l.project_id = @project_id

      # set caller location
      if Rails.application.config.google_cloudrun.logger_source_location
        loc = caller_locations(3, 1)&.first
        if loc
          l.location_path = loc.path
          l.location_line = loc.lineno
          l.location_method = loc.label
        end
      end

      # attach user to entry
      p = Rails.application.config.google_cloudrun.logger_user
      if p && p.is_a?(Proc)
        begin
          l.user = p.call(current_request)
        rescue
          raise
          # TODO ignore or log?
        end
      end

      @out.puts l.to_json
    end

    def write_error_report(severity, msg, labels)
      l = ErrorReportingEntry.new
      l.severity = severity
      l.request = current_request
      l.labels = labels
      l.message = msg
      l.project_id = @project_id

      # set caller location
      loc = caller_locations(3, 1)&.first
      if loc
        l.location_path = loc.path
        l.location_line = loc.lineno
        l.location_method = loc.label
      end

      # set context
      l.context_service = GoogleCloudRun.k_service
      l.context_version = GoogleCloudRun.k_revision

      # attach user to entry
      p = Rails.application.config.google_cloudrun.error_reporting_user
      if p && p.is_a?(Proc)
        begin
          l.user = p.call(current_request)
        rescue
          # TODO ignore or log?
        end
      end

      @out.puts l.to_json
    end

    def current_request
      Thread.current[thread_key]
    end

    def thread_key
      # We use our object ID here to avoid conflicting with other instances
      thread_key = @thread_key ||= "google_cloudrun_logging_request:#{object_id}"
    end
  end

  class LoggerMiddleware
    def initialize(app)
      @app = app
    end

    # A middleware which injects the request into the Rails.logger
    def call(env)
      request = ActionDispatch::Request.new(env)
      Rails.logger.inject_request(request)
      @app.call(env)
    ensure
      ActiveSupport::LogSubscriber.flush_all!
    end
  end

  class DummyFormatter < ::Logger::Formatter
    def call(severity, timestamp, progname, msg)
      # we bypass all formatters
    end
  end

  module SilenceExceptions
    private

    def log_error(_request, wrapper)
      exception = wrapper.exception
      return if Rails.application.config.google_cloudrun.silence_exceptions.any? { |e| exception.is_a?(e) }
      super
    end
  end
end
