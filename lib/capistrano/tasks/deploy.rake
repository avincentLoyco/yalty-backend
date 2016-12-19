namespace :deploy do
  task :database do
    on running_task_server do
      within release_path do
        next unless test 'rake db:pending'
      end
    end
    invoke 'maintenance:on'
    invoke 'database:migrate'
  end

  desc 'Restart servers and workers'
  task :restart do
  end

  before 'deploy:publishing', 'deploy:database'
  after 'deploy:publishing', 'deploy:restart'
  after 'deploy:publishing', 'maintenance:off'
end
