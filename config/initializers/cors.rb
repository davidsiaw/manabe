# frozen_string_literal: true

# FRONTEND_HOSTS lists the frontend origins allowed to call the API, comma
# separated, e.g. "https://learn.example.com,https://m.example.com". The older
# single-valued FRONTEND_HOST is still read. Unset means any origin (dev).
frontend_hosts = ENV.fetch('FRONTEND_HOSTS') { ENV.fetch('FRONTEND_HOST', '*') }
                    .split(',').map(&:strip).reject(&:empty?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*frontend_hosts)

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head]
  end
end
