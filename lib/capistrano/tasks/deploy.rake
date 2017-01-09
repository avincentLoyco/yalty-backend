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

  task :quiet_workers do
    on roles(%w(worker)) do
      execute(:sudo, '/etc/init.d/app-03 quiet')
    end
  end

  after 'deploy:starting', 'deploy:quiet_workers'
  before 'deploy:publishing', 'deploy:enable_maintenance'
  before 'deploy:publishing', 'deploy:migrate_database'
  after 'deploy:publishing', 'restart:all'
  after 'deploy:publishing', 'maintenance:off'
end
