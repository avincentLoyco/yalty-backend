require File.expand_path('../boot', __FILE__)

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require_relative '../lib/sidekiq/custom_job_adapter.rb'
require 'csv'
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

begin
  Dotenv::Railtie.load
rescue NameError
end

module Yalty
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # add middlewares to load path
    config.autoload_once_paths << config.root.join('lib', 'middlewares')
    config.autoload_once_paths << config.root.join('lib', 'attributes')
    config.autoload_once_paths << config.root.join('lib', 'sidekiq')
    config.autoload_once_paths << config.root.join('lib', 'doorkeeper')

    config.eager_load_paths << config.root.join('app', 'services', 'employee_balance')
    config.eager_load_paths << config.root.join('app', 'services', 'schedule')
    config.eager_load_paths << config.root.join('app', 'services', 'event')

    # Genrators
    config.generators do |g|
      g.orm                 :active_record
      g.template_engine     nil

      g.assets              false
      g.stylesheets         false
      g.stylesheet_engine   nil
      g.javascripts         false
      g.helper              false

      g.test_framework      :rspec, fixtures: true
      g.view_specs          false
      g.request_specs       false
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end

    # CORS configuration
    config.middleware.insert_before 0, 'Rack::Cors', debug: !Rails.env.production?, logger: (-> { Rails.logger }) do
      allow do
        origins '*'

        resource '*',
          headers: :any,
          methods: %i(get post delete put patch options head),
          max_age: 0
      end
    end

    # Support Maintenance Mode Middleware
    config.middleware.insert_after('Rack::Cors', 'MaintenanceModeMiddleware')
    # Answer to ping request Middleware
    config.middleware.insert_after('MaintenanceModeMiddleware', 'PingMiddleware')

    # Remove Content-Type header in response with status 205
    config.middleware.use('RemoveContentTypeHeader')

    # Set current user
    config.middleware.use('CurrentUserMiddleware')
    # Set current account
    config.middleware.insert_after('CurrentUserMiddleware', 'CurrentAccountMiddleware')

    # Etag
    config.middleware.insert_before 'Rack::ETag', 'ETagMiddleware'

    # SQL database schema
    config.active_record.schema_format = :sql

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :fr, :de]

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # SMTP configuration
    config.action_mailer.delivery_method = :test
    config.action_mailer.smtp_settings = {
      address:              ENV['SMTP_ADDRESS'],
      port:                 ENV['SMTP_PORT'],
      domain:               'yalty.io',
      user_name:            ENV['SMTP_USERNAME'],
      password:             ENV['SMTP_PASSWORD'],
      authentication:       'plain',
      enable_starttls_auto: true
    }

    # Active Job adapter
    config.active_job.queue_adapter = CustomJobAdapter

    # File upload root path
    config.file_upload_root_path = begin
      path = Pathname.new(ENV['FILE_STORAGE_UPLOAD_PATH'] || 'file')
      path = path.expand_path(File.join(__dir__, '..')) unless path.absolute?
      path
    end

    # Match Paperclip path with the one from Rake app
    config.paperclip_defaults = {
      path: config.file_upload_root_path.join(':id/:style/:filename').to_s
    }

    # Date when new occupation rate logic is active, it is IMPORTANT to be triple sure when
    # changing it. Since that date some calculation behave differently and logic before that for
    # existing accounts is blocked.
    config.migration_date = Date.new(2018, 1, 1)
  end

  #
  # Yalty config accessors
  #
  module_function

  # list of reserved subdomains (not valid for account subdomin)
  def reserved_subdomains
    @reserved_subdomains ||= %w(www staging review) + ENV['RESERVED_SUBDOMAINS'].to_s.split(' ')
  end
end
