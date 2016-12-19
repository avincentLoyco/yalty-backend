namespace :database do
  desc 'Run database migrations'
  task :migrate do
    on running_task_server do
      within release_path do
        info 'Migrate database'
        execute :rake, 'db:migrate'
      end
    end
  end
end
