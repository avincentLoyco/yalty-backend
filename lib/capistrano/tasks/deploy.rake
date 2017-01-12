namespace :deploy do
  task :enable_maintenance do
    invoke 'maintenance:on' if fetch(:maintenance_mode, false)
  end

  task :migrate_database do
    on fetch(:migration_server) do
      if test(:diff, "-qr #{release_path}/db #{current_path}/db")
        info 'Skip migration because not new migration files found'
        invoke 'deploy:rake:before_migrate_database'
        invoke 'deploy:rake:after_migrate_database'
      else
        invoke 'maintenance:on'
        invoke 'deploy:rake:before_migrate_database'
        invoke 'db:migrate'
        invoke 'deploy:rake:after_migrate_database'
      end
    end
  end

  task :quiet_workers do
    on roles(%w(worker)) do
      execute(:sudo, '/etc/init.d/app-03 quiet')
    end
  end

  namespace :rake do
    task :before_migrate_database do
      on fetch(:running_task_server) do
        within release_path do
          fetch(:tasks_before_migration, []).each do |task|
            execute :rake, task
          end
        end
      end
    end

    task :after_migrate_database do
      on fetch(:running_task_server) do
        within release_path do
          fetch(:tasks_after_migration, []).each do |task|
            execute :rake, task
          end
        end
      end
    end
  end

  after 'deploy:starting', 'deploy:quiet_workers'
  before 'deploy:publishing', 'deploy:enable_maintenance'
  before 'deploy:publishing', 'deploy:migrate_database'
  after 'deploy:publishing', 'restart:all'
  after 'deploy:publishing', 'maintenance:off'
  after 'deploy:publishing', 'newrelic:notice_deployment'
end
