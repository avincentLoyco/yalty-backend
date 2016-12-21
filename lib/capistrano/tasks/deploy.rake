namespace :deploy do
  task :enable_maintenance do
    invoke 'maintenance:on' if fetch(:maintenance_mode, false)
  end

  task :migrate_database do
    on fetch(:migration_server) do
      if test(:diff, "-qr #{release_path}/db #{current_path}/db")
        info 'Skip migration because not new migration files found'
      else
        invoke 'maintenance:on'
        invoke 'db:migrate'
      end
    end
  end

  namespace :backend do
    desc 'Start backend servers'
    task :start do
      on roles(%w(api launchpad)) do
        execute(:sudo, :systemctl, :start, fetch(:backend_service_name))
      end
    end

    desc 'Stop backend servers'
    task :stop do
      on roles(%w(api launchpad)) do
        execute(:sudo, :systemctl, :stop, fetch(:backend_service_name))
      end
    end

    desc 'Restart backend servers (phased-restart if maintenance mode is active)'
    task :restart do
      command = fetch(:maintenance_mode, false) ? :restart : :reload

      on roles(%w(api launchpad)) do
        execute(:sudo, :systemctl, command, fetch(:backend_service_name))
      end
    end
  end

  namespace :worker do
    desc 'Start workers'
    task :start do
      on roles(%w(worker)) do
        execute(:sudo, :systemctl, :start, fetch(:worker_service_name))
      end
    end

    desc 'Stop workers'
    task :stop do
      on roles(%w(worker)) do
        execute(:sudo, :systemctl, :stop, fetch(:worker_service_name))
      end
    end

    desc 'Restart workers'
    task :restart do
      on roles(%w(worker)) do
        execute(:sudo, :systemctl, :restart, fetch(:worker_service_name))
      end
    end

    desc 'Ask workers to not take new job'
    task :quiet do
      on roles(%w(worker)) do
        execute(:sudo, '/etc/init.d/app-03 quiet')
      end
    end
  end

  after 'deploy:starting', 'deploy:worker:quiet'
  before 'deploy:publishing', 'deploy:enable_maintenance'
  before 'deploy:publishing', 'deploy:migrate_database'
  after 'deploy:publishing', 'deploy:backend:restart'
  after 'deploy:publishing', 'deploy:worker:restart'
  after 'deploy:publishing', 'maintenance:off'
end
