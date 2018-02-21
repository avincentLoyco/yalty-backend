def systemctl(command, service)
  execute(:sudo, :systemctl, command, service)
rescue SSHKit::Command::Failed => e
  if command == :reload
    command = :restart
    retry
  elsif command == :restart
    command = :start
    retry
  else
    raise e
  end
end

namespace :start do
  desc "Start all services"
  task :all do
    invoke "start:backend"
    invoke "start:worker"
  end

  desc "Start backend service"
  task :backend do
    on roles(%w(api launchpad)) do
      systemctl(:start, fetch(:backend_service_name))
    end
  end

  desc "Start worker service"
  task :worker do
    on roles(%w(worker)) do
      systemctl(:start, fetch(:worker_service_name))
    end
  end
end

namespace :stop do
  desc "Stop all services"
  task :all do
    invoke "deploy:quiet_workers"
    invoke "stop:backend"
    invoke "stop:worker"
  end

  desc "Stop backend service"
  task :backend do
    on roles(%w(api launchpad)) do
      systemctl(:stop, fetch(:backend_service_name))
    end
  end

  desc "Stop worker service"
  task :worker do
    on roles(%w(worker)) do
      systemctl(:stop, fetch(:worker_service_name))
    end
  end
end

namespace :restart do
  desc "Restart all services"
  task :all do
    invoke "deploy:quiet_workers"
    invoke "restart:backend"
    invoke "restart:worker"
  end

  desc "Restart backend service (phased-restart if maintenance mode is active)"
  task :backend do
    command = fetch(:maintenance_mode_enable, false) ? :restart : :reload

    on roles(%w(api launchpad)) do
      systemctl(command, fetch(:backend_service_name))
    end
  end

  desc "Restart worker service"
  task :worker do
    on roles(%w(worker)) do
      systemctl(:restart, fetch(:worker_service_name))
    end
  end
end
