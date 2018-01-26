workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads Integer(ENV['MIN_THREADS'] || ENV['MAX_THREADS'] || 5), Integer(ENV['MAX_THREADS'] || 5)

rackup      DefaultRackup

rails_env = ENV['RAILS_ENV'] || 'development'
environment rails_env
directory File.expand_path('..', __dir__)

if %w(production staging).include?(rails_env)
  logfile = File.expand_path('../log/puma.log', __dir__)
  stdout_redirect logfile, logfile, true
end

pidfile File.expand_path('../tmp/pids/puma.pid', __dir__)

worker_timeout 30
worker_boot_timeout 60

# Production config
if ENV['PUMA_BINDING']
  bind ENV['PUMA_BINDING']

  prune_bundler

# Development config
else
  port ENV['RAILS_PORT'] || ENV['PORT'] || 3000

  preload_app!
end

on_worker_boot do |worker|
  begin
    # Worker specific setup for Rails 4.1+
    # See: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
    if defined?(ActiveSupport)
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.establish_connection
      end
    end

    # Create pid file for each worker
    next unless Puma.respond_to? :cli_config

    if pidfile = Puma.cli_config.options[:pidfile]
      File.write(pidfile.gsub(/(.+?)(\.pid)?$/, "\\1.#{worker}\\2"), Process.pid)
    end
  rescue => e
    puts 'Error on worker boot hook in config/puma.rb:', e.message, e.backtrace
  end
end
