namespace :start do
  desc 'Start all services'
  task :all do
    invoke 'start:backend'
    invoke 'start:worker'
  end

  desc 'Start backend service'
  task :backend do
    on roles(%w(api launchpad)) do
      execute(:sudo, :systemctl, :start, fetch(:backend_service_name))
    end
  end

  desc 'Start worker service'
  task :start do
    on roles(%w(worker)) do
      execute(:sudo, :systemctl, :start, fetch(:worker_service_name))
    end
  end
end

namespace :stop do
  desc 'Stop all services'
  task :all do
    invoke 'stop:backend'
    invoke 'stop:worker'
  end

  desc 'Stop backend service'
  task :stop do
    on roles(%w(api launchpad)) do
      execute(:sudo, :systemctl, :stop, fetch(:backend_service_name))
    end
  end

  desc 'Stop worker service'
  task :stop do
    on roles(%w(worker)) do
      execute(:sudo, :systemctl, :stop, fetch(:worker_service_name))
    end
  end
end

namespace :restart do
  desc 'Restart all services'
  task :all do
    invoke 'restart:backend'
    invoke 'restart:worker'
  end

  desc 'Restart backend service (phased-restart if maintenance mode is active)'
  task :backend do
    command = fetch(:maintenance_mode, false) ? :restart : :reload

    on roles(%w(api launchpad)) do
      execute(:sudo, :systemctl, command, fetch(:backend_service_name))
    end
  end

  desc 'Restart worker service'
  task :worker do
    on roles(%w(worker)) do
      execute(:sudo, :systemctl, :restart, fetch(:worker_service_name))
    end
  end
end
