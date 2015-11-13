require File.expand_path('../boot', __FILE__)

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "action_view/railtie"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Yalty
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # add middlewares to load path
    config.autoload_once_paths << config.root.join('lib', 'middlewares')
    config.autoload_once_paths << config.root.join('lib', 'attributes')

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

    # Set current user
    config.middleware.insert_after('Rack::ETag', 'CurrentUserMiddleware')
    # Set current account
    config.middleware.insert_after('CurrentUserMiddleware', 'CurrentAccountMiddleware')

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

    # SQL database schema
    config.active_record.schema_format = :sql

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en

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
