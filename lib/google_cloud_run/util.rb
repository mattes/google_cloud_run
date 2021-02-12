require "net/http"
require "uri"

module GoogleCloudRun
  def self.k_service
    @k_service ||= begin
        ENV.fetch("K_SERVICE", "")
      end
  end

  def self.k_revision
    @k_revision ||= begin
        revision = ENV.fetch("K_REVISION", "")
        service = ENV.fetch("K_SERVICE", "")
        revision.delete_prefix(service + "-")
      end
  end

  # parse_trace_context parses header
  # X-Cloud-Trace-Context: TRACE_ID/SPAN_ID;o=TRACE_TRUE
  def self.parse_trace_context(raw)
    raw&.strip!
    return nil, nil, nil if raw.blank?

    trace = nil
    span = nil
    sample = nil

    first = raw.split("/")
    if first.size > 0
      trace = first[0]
    end

    if first.size > 1
      second = first[1].split(";")

      if second.size > 0
        span = second[0]
      end

      if second.size > 1
        case second[1].delete_prefix("o=")
        when "1"; sample = true
        when "0"; sample = false
        end
      end
    end

    return trace, span, sample
  end

  # project_id returns the current Google project id from the
  # metadata server
  def self.project_id
    return "dummy-project" if Rails.env.test?

    @project_id ||= begin
        uri = URI.parse("http://metadata.google.internal/computeMetadata/v1/project/project-id")
        request = Net::HTTP::Get.new(uri)
        request["Metadata-Flavor"] = "Google"

        req_options = {
          open_timeout: 5,
          read_timeout: 5,
          max_retries: 2,
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        raise "unknown google cloud project" if response.code.to_i != 200

        response.body.strip
      end
  end
  #
  # default_service_account_email returns the default service account's email from the
  # metadata server
  def self.default_service_account_email
    return "123456789-compute@developer.gserviceaccount.com" if Rails.env.test?

    @default_service_account_email ||= begin
        uri = URI.parse("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email")
        request = Net::HTTP::Get.new(uri)
        request["Metadata-Flavor"] = "Google"

        req_options = {
          open_timeout: 5,
          read_timeout: 5,
          max_retries: 2,
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        raise "unknown google default service account" if response.code.to_i != 200

        response.body.strip
      end
  end
end
