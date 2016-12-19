namespace :maintenance do
  desc 'Turn maintenance mode on'
  task :on do
    on running_task_server do
      within release_path do
        info 'Turn maintenance mode on'
        execute :rake, 'maintenance:on'
      end
    end
  end

  desc 'Turn maintenance mode off'
  task :off do
    on running_task_server do
      within release_path do
        info 'Turn maintenance mode off'
        execute :rake, 'maintenance:off'
      end
    end
  end
end
