module GoogleCloudRun
  class RequestId
    def initialize(app)
      @app = app
    end

    # A middleware to replace X-Request-Id with X-Cloud-Trace-Context's Trace ID
    # ref: https://github.com/rails/rails/blob/6-1-stable/actionpack/lib/action_dispatch/middleware/request_id.rb
    # ref: https://github.com/Octo-Labs/heroku-request-id/blob/master/lib/heroku-request-id/railtie.rb
    def call(env)
      req = ActionDispatch::Request.new env
      trace, _, _ = GoogleCloudRun.parse_trace_context(req.headers["X-Cloud-Trace-Context"])
      @app.call(env).tap { |_status, headers, _body| headers["X-Request-Id"] = trace }
    end
  end
end
