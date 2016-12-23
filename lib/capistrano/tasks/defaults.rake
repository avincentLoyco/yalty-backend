namespace :load do
  task :defaults do
    set :pty, true

    set :running_task_server, -> { primary(fetch(:running_task_role, :worker)) }
    set :migration_server, -> { primary(fetch(:running_task_role, :worker)) }
    set :running_console_server, -> { primary(fetch(:running_task_role, :worker)) }

    set :app_version, -> {
      begin
        File.read(File.expand_path('../../../VERSION', __dir__)).strip
      rescue
        'VERSION file cannot be read'
      end
    }

    set :rbenv_ruby, -> {
      path = File.expand_path('../../../Gemfile', __dir__)
      File.read(path).match(/ruby '([^']+)'/)[1]
    }
    set :rbenv_bundler, -> {
      path = File.expand_path('../../../Gemfile.lock', __dir__)
      File.read(path).match(/BUNDLED WITH\n(.+)/)[1].strip
    }
  end
end
