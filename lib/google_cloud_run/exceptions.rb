module GoogleCloudRun
  def self.exception_interceptor(request, exception)

    # ref: https://cloud.google.com/error-reporting/reference/rest/v1beta1/projects.events/report#reportederrorevent

    return false if Rails.application.config.google_cloudrun.silence_exceptions.any? { |e| exception.is_a?(e) }

    l = ErrorReportingEntry.new
    l.project_id = GoogleCloudRun.project_id
    l.severity = Rails.application.config.google_cloudrun.error_reporting_exception_severity
    l.exception = exception
    l.request = request

    l.context_service = GoogleCloudRun.k_service
    l.context_version = GoogleCloudRun.k_revision

    # attach user to entry
    p = Rails.application.config.google_cloudrun.error_reporting_user
    if p && p.is_a?(Proc)
      begin
        l.user = p.call(request)
      rescue
        # TODO ignore or log?
      end
    end

    Rails.application.config.google_cloudrun.out.puts l.to_json
    Rails.application.config.google_cloudrun.out.flush

    return true
  end
end
