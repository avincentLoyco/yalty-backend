namespace :load do
  task :defaults do
    set :running_task_server, -> { primary(fetch(:running_task_role, :worker)) }
    set :migration_server, -> { primary(fetch(:running_task_role, :worker)) }
  end
end
