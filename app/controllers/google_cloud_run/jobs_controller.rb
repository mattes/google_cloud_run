module GoogleCloudRun
  class JobsController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def callback
      # verify User-Agent and Content-Type
      return head :bad_request unless request.user_agent == "Google-Cloud-Tasks"
      return head :bad_request unless request.headers["Content-type"].include?("application/json")
      return head :bad_request unless request.headers["Authorization"].start_with?("Bearer")

      # verify Bearer token
      begin
        r = Google::Auth::IDTokens.verify_oidc request.headers["Authorization"]&.delete_prefix("Bearer")&.strip
      rescue => e
        Rails.logger.warning "Google Cloud Run Job callback failed: #{e.message}"
        return head :bad_request
      end

      # parse JSON body
      begin
        body = JSON.parse(request.body.read)
      rescue => e
        raise "Google Cloud Run Job callback failed: Unable to parse JSON body: #{e.message}"
      end

      # execute the job
      ActiveJob::Base.execute body

      head :ok
    end
  end
end
