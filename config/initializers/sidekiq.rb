require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq/scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['RAILS_SIDEKIQ_REDIS'] || 'redis://localhost:6379' }
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_scheduler.yml', __FILE__))
    Sidekiq::Scheduler.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['RAILS_SIDEKIQ_REDIS'] || 'redis://localhost:6379' }
end
