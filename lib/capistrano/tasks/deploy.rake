require 'json'

namespace :deploy do
  task :failed do
    on release_roles(fetch(:docker_roles)) do
      execute :rm, '-rf', release_path, raise_on_non_zero_exit: false
    end
    invoke 'restart:worker'
  end

  task :enable_maintenance do
    invoke 'maintenance:on' if fetch(:maintenance_mode, false)
  end

  task :migrate_database do
    stage = fetch(:stage)
    do_migrate = false

    on fetch(:migration_server) do
      do_migrate = (stage == :staging) || !test(:diff, "-qr #{release_path}/db #{current_path}/db")
      invoke 'maintenance:on' if do_migrate
    end

    invoke 'db:dump'
    invoke 'deploy:rake:before_migrate_database'

    on fetch(:migration_server) do
      if do_migrate
        invoke 'db:migrate'
      else
        info 'Skip migration because not new migration files found'
      end
    end

    invoke 'deploy:rake:after_migrate_database'
  end

  task :quiet_workers do
    on roles(%w(worker)) do
      execute(:sudo, '/etc/init.d/app-03 quiet') if test "[ -d #{current_path} ]"
    end
  end

  task :permissions do
    on release_roles(fetch(:docker_roles)) do
      execute :chmod, '-R', 'g=u', release_path
    end
  end

  task :clean_tasks_json do
    # do we have access to version?
    version = fetch(:app_version)

    tasks_file = File.expand_path('../../../config/deploy/tasks.json', __dir__)
    tasks_json = JSON.parse(File.read(tasks_file))
    tasks_json['before_migration'].clear
    tasks_json['after_migration'].clear

    # what locally means in this task?
    run_locally do
      info 'Cleanup tasks list'
      File.write(tasks_file, JSON.pretty_generate(tasks_json))
      if test "git diff-index --ignore-space-change --quiet v#{version} -- #{tasks_file}"
        info 'nothing to do...'
      else
        # do we have access to git?
        execute :git, :add, tasks_file
        execute :git, :commit, '-m "Cleanup list of deploy tasks"'
        execute :git, :push, "-u origin releases/#{version}"
      end
    end
  end

  namespace :rake do
    task :before_migrate_database do
      on fetch(:running_task_server) do
        within release_path do
          tasks = JSON.parse(capture(:cat, 'config/deploy/tasks.json'))
          tasks['before_migration'].each do |task|
            execute :rake, task['task_name']
          end
        end
      end
    end

    task :after_migrate_database do
      on fetch(:running_task_server) do
        within release_path do
          tasks = JSON.parse(capture(:cat, 'config/deploy/tasks.json'))
          tasks['after_migration'].each do |task|
            execute :rake, task['task_name']
          end
        end
      end
    end
  end

  after 'deploy:starting', 'deploy:quiet_workers'
  after 'docker_copy:create_release', 'deploy:permissions'
  before 'deploy:publishing', 'deploy:enable_maintenance'
  before 'deploy:publishing', 'deploy:migrate_database'
  after 'deploy:publishing', 'restart:all'
  after 'deploy:publishing', 'maintenance:off'
  # after 'deploy:publishing', 'newrelic:notice_deployment'
end
