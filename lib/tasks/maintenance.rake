require 'redis'

namespace :maintenance do
  desc 'Turn maintenance mode on'
  task :on do
    Redis.current.set('maintenance_mode', true)
  end

  desc 'Turn maintencne mode off'
  task :off do
    Redis.current.set('maintenance_mode', false)
  end
end
