Rails.application.routes.draw do
  post Rails.application.config.google_cloudrun.job_callback_path => "google_cloud_run/jobs#callback", as: :rails_google_cloudrun_job_callback
end
