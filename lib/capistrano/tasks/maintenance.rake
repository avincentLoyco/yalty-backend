namespace :maintenance do
  desc 'Turn maintenance mode on'
  task :on do
    on fetch(:running_task_server) do
      within release_path do
        info 'Turn maintenance mode on'
        execute :rake, 'maintenance:on'
        set(:maintenance_mode_enable, true)
      end
    end
  end

  desc 'Turn maintenance mode off'
  task :off do
    next if fetch(:maintenance_mode, false)

    on fetch(:running_task_server) do
      within release_path do
        info 'Turn maintenance mode off'
        execute :rake, 'maintenance:off'
      end
    end
  end
end

task :maintenance do
  set(:maintenance_mode, true)
end
