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
      on roles(%w(api launchpad), in: :sequence, wait: 5) do
        within current_path do
          execute(:'./bin/pumactl', '-C', File.join(current_path, 'config/puma.rb'), :start)
        end
      end
    end

    desc 'Stop backend servers'
    task :stop do
      on roles(%w(api launchpad), in: :sequence, wait: 5) do
        within current_path do
          execute(:'./bin/pumactl', '-C', File.join(current_path, 'config/puma.rb'), :stop)
        end
      end
    end

    desc 'Restart backend servers (phased-restart if maintenance mode is active)'
    task :restart do
      command = fetch(:maintenance_mode, false) ? :restart : :'phased-restart'

      on roles(%w(worker)) do
        within current_path do
          execute(:'./bin/pumactl', '-C', File.join(current_path, 'config/puma.rb'), command)
        end
      end
    end
  end

  namespace :worker do
    desc 'Start workers'
    task :start do
      on roles(%w(worker)) do
        within current_path do
          execute(:'./bin/sidekiqctl', '-C', File.join(current_path, 'config/sidekiq.yml'), :start)
        end
      end
    end

    desc 'Stop workers'
    task :stop do
      on roles(%w(worker)) do
        within current_path do
          execute(:'./bin/sidekiqctl', '-C', File.join(current_path, 'config/sidekiq.yml'), :stop)
        end
      end
    end

    desc 'Restart workers'
    task :restart do
      invoke 'deploy:worker:stop'
      invoke 'deploy:worker:start'
    end

    desc 'Ask workers to not take new job'
    task :quiet do
      on roles(%w(worker)) do
        within current_path do
          execute(:'./bin/sidekiqctl', '-C', File.join(current_path, 'config/sidekiq.yml'), :quiet)
        end
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
