namespace :database do
  desc 'Run database migrations'
  task :migrate do
    on release_roles(:all) do
      within release_path do
        execute :rake, 'db:migrate'
      end
    end
  end
end
