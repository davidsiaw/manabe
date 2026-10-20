# frozen_string_literal: true

# The admin signs in at /admins/sign_in for /sidekiq and /swagger. Production
# must set ADMIN_EMAIL and ADMIN_PASSWORD; the defaults are for development.
Admin.find_or_create_by!(email: ENV.fetch('ADMIN_EMAIL', 'admin@example.com')) do |admin|
  admin.password = ENV.fetch('ADMIN_PASSWORD', 'asdasd')
end
