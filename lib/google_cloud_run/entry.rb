module GoogleCloudRun
  class LogEntry
    include ::Logger::Severity

    attr_accessor :severity,
                  :message,
                  :labels,
                  :timestamp,
                  :request,
                  :user,
                  :location_path, :location_line, :location_method,
                  :project_id

    def initialize
      @severity = G_DEFAULT
      @timestamp = Time.now.utc
      @insert_id = SecureRandom.uuid
    end

    def to_json
      raise "labels must be hash" if !@labels.blank? && !@labels.is_a?(Hash)

      labels["user"] = @user unless @user.blank?

      j = {}

      j["logging.googleapis.com/insertId"] = @insert_id
      j["severity"] = Severity.to_s(Severity.mapping(@severity))
      j["message"] = @message.is_a?(String) ? @message.strip : @message.inspect
      j["timestampSeconds"] = @timestamp.to_i
      j["timestampNanos"] = @timestamp.nsec
      j["logging.googleapis.com/labels"] = @labels unless @labels.blank?

      if @request
        # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#httprequest
        j["httpRequest"] = {}
        j["httpRequest"]["requestMethod"] = @request&.method.to_s
        j["httpRequest"]["requestUrl"] = @request&.url.to_s
        j["httpRequest"]["userAgent"] = @request&.headers["user-agent"].to_s unless @request&.headers["user-agent"].blank?
        j["httpRequest"]["remoteIp"] = @request&.remote_ip.to_s
        j["httpRequest"]["referer"] = @request&.headers["referer"].to_s unless @request&.headers["referer"].blank?

        trace, span, sample = GoogleCloudRun.parse_trace_context(@request&.headers["X-Cloud-Trace-Context"])
        j["logging.googleapis.com/trace"] = "projects/#{@project_id}/traces/#{trace}" unless trace.blank?
        j["logging.googleapis.com/spanId"] = span unless span.blank?
        j["logging.googleapis.com/trace_sampled"] = sample unless sample.nil?
      end

      if @location_path || @location_line || @location_method
        j["logging.googleapis.com/sourceLocation"] = {}
        j["logging.googleapis.com/sourceLocation"]["function"] = @location_method.to_s
        j["logging.googleapis.com/sourceLocation"]["file"] = @location_path.to_s
        j["logging.googleapis.com/sourceLocation"]["line"] = @location_line.to_i
      end

      j.to_json
    end
  end

  # https://cloud.google.com/error-reporting/reference/rest/v1beta1/projects.events/report#ReportedErrorEvent
  # https://cloud.google.com/error-reporting/docs/formatting-error-messages
  class ErrorReportingEntry
    include ::Logger::Severity

    attr_accessor :severity,
                  :exception,
                  :project_id,
                  :message,
                  :labels,
                  :timestamp,
                  :request,
                  :user,
                  :location_path, :location_line, :location_method,
                  :context_service, :context_version

    def initialize
      @severity = G_CRITICAL
      @timestamp = Time.now.utc
      @insert_id = SecureRandom.uuid
    end

    def to_json
      raise "labels must be hash" if !@labels.blank? && !@labels.is_a?(Hash)

      j = {}

      j["@type"] = "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent"
      j["logging.googleapis.com/insertId"] = @insert_id
      j["severity"] = Severity.to_s(Severity.mapping(@severity))
      j["eventTime"] = @timestamp.strftime("%FT%T.%9NZ")
      j["logging.googleapis.com/labels"] = @labels unless @labels.blank?

      if @context_service || @context_version
        j["serviceContext"] = {}
        j["serviceContext"]["service"] = @context_service.to_s
        j["serviceContext"]["version"] = @context_version.to_s
      end

      if @request
        # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#httprequest
        j["httpRequest"] = {}
        j["httpRequest"]["requestMethod"] = @request&.method.to_s
        j["httpRequest"]["requestUrl"] = @request&.url.to_s
        j["httpRequest"]["userAgent"] = @request&.headers["user-agent"].to_s unless @request&.headers["user-agent"].blank?
        j["httpRequest"]["remoteIp"] = @request&.remote_ip.to_s
        j["httpRequest"]["referer"] = @request&.headers["referer"].to_s unless @request&.headers["referer"].blank?

        trace, span, sample = GoogleCloudRun.parse_trace_context(@request&.headers["X-Cloud-Trace-Context"])
        j["logging.googleapis.com/trace"] = "projects/#{@project_id}/traces/#{trace}" unless trace.blank?
        j["logging.googleapis.com/spanId"] = span unless span.blank?
        j["logging.googleapis.com/trace_sampled"] = sample unless sample.nil?
      end

      if @exception
        j["message"] = @exception.class.to_s

        e_message = @exception&.message.to_s.strip
        unless e_message.blank?
          j["message"] << ": " + e_message + "\n"
        end

        j["message"] << @exception&.backtrace.join("\n")
      else
        j["message"] = @message.is_a?(String) ? @message.strip : @message.inspect
      end

      j["context"] = {}

      if @request
        # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#httprequest
        j["context"]["httpRequest"] = {}
        j["context"]["httpRequest"]["method"] = @request&.method
        j["context"]["httpRequest"]["url"] = @request&.url
        j["context"]["httpRequest"]["userAgent"] = @request&.headers["user-agent"] unless @request&.headers["user-agent"].blank?
        j["context"]["httpRequest"]["remoteIp"] = @request&.remote_ip
        j["context"]["httpRequest"]["referrer"] = @request&.headers["referer"] unless @request&.headers["referer"].blank?
      end

      if @user
        j["context"]["user"] = @user
      end

      if @location_path || @location_line || @location_method
        j["context"]["reportLocation"] = {}
        j["context"]["reportLocation"]["filePath"] = @location_path.to_s
        j["context"]["reportLocation"]["lineNumber"] = @location_line.to_i
        j["context"]["reportLocation"]["functionName"] = @location_method.to_s
      end

      j.to_json
    end
  end
end
