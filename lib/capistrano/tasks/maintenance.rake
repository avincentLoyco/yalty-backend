namespace :maintenance do
  desc 'Turn maintenance mode on'
  task :on do
    on release_roles(:all) do
      within release_path do
        execute :rake, 'maintenance:on'
      end
    end
  end

  desc 'Turn maintencne mode off'
  task :off do
    on release_roles(:all) do
      within release_path do
        execute :rake, 'maintenance:off'
      end
    end
  end
end
