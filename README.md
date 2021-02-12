# Rails on Google Cloud Run 

* Logging
* Error Reporting
* Active Job Adapter via [Cloud Tasks](https://cloud.google.com/tasks)
* Minor patches for better compatibility
* Works with Ruby 3 and Rails 6


## Usage

```ruby
logger.info "Hello World"

logger.info do
  "Expensive logging operation, only run when logged"
end

logger.info "Labels work, too!", my_label: "works", another_one: "great"
```

All Google Cloud Logging Severities are supported:

```
logger.default (or logger.unknown) - The log entry has no assigned severity level.
logger.debug                       - Debug or trace information. 
logger.info                        - Routine information, such as ongoing status or performance.
logger.notice                      - Normal but significant events, such as start up, shut down, or a configuration change.
logger.warning (or logger.warn)    - Warning events might cause problems.
logger.error                       - Error events are likely to cause problems.
logger.critical (or logger.fatal)  - Critical events cause more severe problems or outages.
logger.alert                       - A person must take an action immediately.
logger.emergency                   - One or more systems are unusable.
```


## Installation

Add the gem to your Gemfile and run `bundle install`.

```ruby
# Gemfile
group :production do
  gem 'google_cloud_run'
end
```


In your production config:

```ruby
# config/environments/production.rb

config.log_level = :g_notice
config.logger = GoogleCloudRun::Logger.new

config.active_job.queue_adapter = :google_cloudrun_tasks
config.google_cloudrun.job_queue_default_region = "us-central1"
config.google_cloudrun.job_callback_url = "https://your-domain.com/rails/google_cloudrun/job_callback"
```

Set the default queue:

```ruby
# app/jobs/application_job.rb
queue_as "my-queue"

# or if `config.google_cloudrun.job_queue_default_region` isn't set:
queue_as "us-central1/my-queue"
```

---

In the default production config, the logger is wrapped around 
a `ENV["RAILS_LOG_TO_STDOUT"].present?` block. I usually just 
remove this block so I don't have to actually set this ENV var.

You can also remove `config.log_formatter` and `config.log_tags` as we don't need it anymore.

I recommend logging `:g_notice` and higher. Rails logs a lot of noise when logging
`:info` and higher.


## Configuration

You can change more settings in `config/environments/production.rb`. See below
for the default configuration.

```ruby
# Enable Google Cloud Logging
config.google_cloudrun.logger = true

# Set output (STDERR or STDOUT)
config.google_cloudrun.out = STDERR

# Add source location (file, line number, method) to each log 
config.google_cloudrun.logger_source_location = true

# Run Proc to assign current user as label to each log
config.google_cloudrun.logger_user = nil


# Enable Error Reporting
config.google_cloudrun.error_reporting = true

# Assign a default severity level to exceptions
config.google_cloudrun.error_reporting_exception_severity = :critical

# Run Proc to assign current user to Error Report
config.google_cloudrun.error_reporting_user = nil

# Turn logs into error reports for this severity and higher.
# Set to nil to disable.
config.google_cloudrun.error_reporting_level = :error

# When log is turned into error report, discard the original
# log and only report the error.
# Set to false to log and report the error at the same time.
config.google_cloudrun.error_reporting_discard_log = true


# Don't log or error report the following exceptions,
# because Cloud Run will create access logs for us already.
config.google_cloudrun.silence_exceptions = [
      ActionController::RoutingError,
      ActionController::MethodNotAllowed,
      ActionController::UnknownHttpMethod,
      ActionController::NotImplemented,
      ActionController::UnknownFormat,
      ActionController::BadRequest,
      ActionController::ParameterMissing,
]


# Set Rails' request id to the trace id from X-Cloud-Trace-Context header
# as set by Cloud Run.
config.google_cloudrun.patch_request_id = true


# Enable Jobs via Cloud Tasks
config.google_cloudrun.jobs = true

# Set the default Google Cloud Task region, i.e. us-central1
config.google_cloudrun.job_queue_default_region = nil

# Google Cloud Tasks will call this url to execute the job
config.google_cloudrun.job_callback_url = nil # required, see above

# The default route for the callback url.
config.google_cloudrun.job_callback_path = "/rails/google_cloudrun/job_callback"

# Time for a job to run in seconds, default is 30min.
# Use `timeout_after 5.minutes` to configure a job individually.
config.google_cloudrun.job_timeout_sec = 1800 # (min 15s, max 30m)
```

---

Both `error_reporting_user` and `logger_user` expect a Proc like this:

```ruby
config.google_cloudrun.logger_user = Proc.new do |request|
  # extract and return user id from request, example:
  request.try { cookie_jar.encrypted[:user_id] }
end
```

---

An example job:

```ruby
class MyJob < ApplicationJob
  queue_as "us-central1/urgent"
  timeout_after 1.minute # min 15s, max 30m, overrides config.google_cloudrun.job_timeout_sec

  def perform(*args)
    # Do something
  end
end
```

## Cloud Task considerations

* Cloud Tasks are a better fit than Google Pub/Sub.
  [Read more](https://cloud.google.com/pubsub/docs/choosing-pubsub-or-cloud-tasks#detailed-feature-comparison)
* I'd recommend to create two different Cloud Run services.
  One for HTTP requests (aka Heroku Dynos) and another service
  for jobs (aka Heroku Workers). Set the `Request Timeout` for 
  the request-bound service to something like `15s`, and for workers
  to `1800s` or match `config.google_cloudrun.job_timeout_sec`.
* Cloud Task execution calls are authenticated with a Google-issued
  OIDC token. So even though `/rails/google_cloudrun/job_callback` is publicly
  available, without a valid token, no job will be executed.
* Cloud Task job processing is async. It supports multiple queues. Delayed jobs
  are natively supported through Cloud Task. Priority jobs are not supported, use
  different queues for that, i.e. "urgent", or "low-priority". Timeouts can be set
  globally or per job-basis (min 15s, max 30m). 
  Retries are natively supported by Cloud Tasks.

