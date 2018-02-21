namespace :load do
  task :defaults do
    set :pty, true

    set :running_task_server, -> { primary(fetch(:running_task_role, :worker)) }
    set :migration_server, -> { primary(fetch(:running_task_role, :worker)) }
    set :running_console_server, -> { primary(fetch(:running_task_role, :worker)) }

    set :app_version, lambda {
      begin
        File.read(File.expand_path("../../../VERSION", __dir__)).strip
      rescue
        "VERSION file cannot be read"
      end
    }

    set :app_version_sha1, lambda {
      version = fetch(:app_version)
      sha1 = nil

      run_locally do
        sha1, = capture(:git, :'ls-remote', "--heads", "origin", "releases/#{version}")
                .split(" ")
      end

      sha1
    }

    set :db_dump_path, lambda {
      timestamp = fetch(:release_timestamp, now)
      File.join(shared_path, "db", "dump.#{timestamp}.pgsql")
    }

    set :rbenv_ruby, File.read(".ruby-version").strip
    set :rbenv_bundler, lambda {
      path = File.expand_path("../../../Gemfile.lock", __dir__)
      File.read(path).match(/BUNDLED WITH\n(.+)/)[1].strip
    }
  end
end
