module GoogleCloudRun
  class Railtie < ::Rails::Railtie
    config.google_cloudrun = ActiveSupport::OrderedOptions.new

    config.google_cloudrun.out = STDERR

    config.google_cloudrun.logger = true
    config.google_cloudrun.logger_source_location = true
    config.google_cloudrun.logger_user = nil

    config.google_cloudrun.error_reporting = true
    config.google_cloudrun.error_reporting_exception_severity = :critical
    config.google_cloudrun.error_reporting_user = nil
    config.google_cloudrun.error_reporting_level = :error
    config.google_cloudrun.error_reporting_discard_log = true

    config.google_cloudrun.silence_exceptions = [
      ActionController::RoutingError,
      ActionController::MethodNotAllowed,
      ActionController::UnknownHttpMethod,
      ActionController::NotImplemented,
      ActionController::UnknownFormat,
      ActionController::BadRequest,
      ActionController::ParameterMissing,
    ]

    config.google_cloudrun.patch_request_id = true

    config.google_cloudrun.jobs = true
    config.google_cloudrun.job_queue_default_region = nil
    config.google_cloudrun.job_callback_url = nil # required
    config.google_cloudrun.job_callback_path = "/rails/google_cloudrun/job_callback"
    config.google_cloudrun.job_timeout_sec = 1800 # 30 min (min 15s, max 30m)

    # ref: https://guides.rubyonrails.org/rails_on_rack.html#internal-middleware-stack

    initializer "google_cloud_run" do |app|
      if app.config.google_cloudrun.error_reporting
        ActionDispatch::DebugExceptions.register_interceptor GoogleCloudRun.method(:exception_interceptor)
      end

      if app.config.google_cloudrun.logger
        app.config.middleware.insert_after Rails::Rack::Logger, GoogleCloudRun::LoggerMiddleware
      end

      if app.config.google_cloudrun.patch_request_id
        app.config.middleware.insert_before ActionDispatch::RequestId, GoogleCloudRun::RequestId
      end

      # https://stackoverflow.com/a/52475865/2142441
      if config.google_cloudrun.silence_exceptions.size > 0
        ActiveSupport.on_load(:action_controller) do
          ActionDispatch::DebugExceptions.prepend GoogleCloudRun::SilenceExceptions
        end
      end

      ActiveJob::Base.send(:include, GoogleCloudRun::TimeoutAfterExtension)
    end
  end
end
