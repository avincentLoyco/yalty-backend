namespace :db do
  desc 'Run database migrations'
  task :migrate do
    on fetch(:migration_server) do
      within release_path do
        info 'Run database migration'
        execute :rake, 'db:migrate'
      end
    end
  end
end
