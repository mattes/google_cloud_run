module ActiveJob
  module QueueAdapters
    class GoogleCloudrunTasksAdapter
      def initialize
        @client = Google::Cloud::Tasks.cloud_tasks
        @project_id = GoogleCloudRun.project_id
        @service_account_email = GoogleCloudRun.default_service_account_email
        @default_job_timeout_sec = Rails.application.config.google_cloudrun.job_timeout_sec
        @job_callback_url = Rails.application.config.google_cloudrun.job_callback_url
        @queue_default_region = Rails.application.config.google_cloudrun.job_queue_default_region

        if @job_callback_url.blank? || !@job_callback_url.end_with?(Rails.application.config.google_cloudrun.job_callback_path)
          raise "Set config.google_cloudrun.job_callback_url to 'https://your-domain.com#{Rails.application.config.google_cloudrun.job_callback_path}'"
        end

        if !@job_callback_url.start_with?("https://")
          raise "config.google_cloudrun.job_callback_url must start with https://"
        end
      end

      def enqueue(job)
        create_cloudtask(job.class,
                         job.job_id,
                         job.queue_name,
                         local_timeout(job) || @default_job_timeout_sec,
                         nil,
                         job.serialize)
      end

      def enqueue_at(job, timestamp)
        create_cloudtask(job.class,
                         job.job_id,
                         job.queue_name,
                         local_timeout(job) || @default_job_timeout_sec,
                         timestamp,
                         job.serialize)
      end

      private

      def create_cloudtask(job_name, job_id, full_queue_name, job_timeout, scheduled_at, job)
        return if !Rails.application.config.google_cloudrun.jobs

        region, queue_name = parse_full_queue_name(full_queue_name)
        queue = @client.queue_path project: @project_id, location: region, queue: queue_name

        task = build_task_request(
          "projects/#{@project_id}/locations/#{region}/queues/#{queue_name}/tasks/#{job_id}",
          @job_callback_url,
          @service_account_email,
          job.to_json,
          job_timeout,
          scheduled_at,
        )

        response = nil
        begin
          response = @client.create_task parent: queue, task: task
        rescue => e
          raise "Failed sending job #{job_name}(#{job_id}) to queue '#{region}/#{queue_name}'. #{e.message}"
        end
        if response.nil?
          raise "Failed sending job #{job_name}(#{job_id}) to queue '#{region}/#{queue_name}'. Google didn't return a response."
        end

        Rails.logger&.notice "Job #{job_name}(#{job_id}) sent to queue '#{region}/#{queue_name}'"
      end

      def build_task_request(name, url, service_account_email, body, job_timeout, scheduled_at)
        # ref: https://cloud.google.com/tasks/docs/reference/rest/v2/projects.locations.queues.tasks#Task
        req = {
          name: name,
          http_request: {
            oidc_token: { service_account_email: service_account_email },
            headers: { "Content-Type": "application/json" },
            http_method: "POST",
            url: url,
            body: body,
          },
        }

        d = Google::Protobuf::Duration.new
        d.seconds = job_timeout.to_i
        req[:dispatch_deadline] = d

        if scheduled_at
          t = Google::Protobuf::Timestamp.new
          t.seconds = Time.at(scheduled_at).utc.to_i
          req[:schedule_time] = t
        end

        return req
      end

      def parse_full_queue_name(queue_name)
        # config.active_job.queue_name_prefix will add an underscore,
        # queue names can't have underscores. Let's turn it into a hyphen.
        queue_name = queue_name.gsub("_", "-")

        # see if we have something like this: region/queue
        parts = queue_name.split("/")
        if parts.size == 2
          return parts[0], parts[1]
        end

        if @queue_default_region.blank?
          raise "queue_as \"#{queue_name}\" needs region: \"region/#{queue_name}\" or set config.google_cloudrun.job_queue_default_region"
        end

        # use our default region
        return @queue_default_region, queue_name
      end

      def local_timeout(job)
        begin
          job.class.class_variable_get(:@@google_cloudrun_job_timeout)
        rescue
          nil
        end
      end
    end
  end
end

module GoogleCloudRun
  module TimeoutAfterExtension
    extend ActiveSupport::Concern

    class_methods do
      def timeout_after(t)
        self.class_variable_set(:@@google_cloudrun_job_timeout, t)
      end
    end
  end
end
