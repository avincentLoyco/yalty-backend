lock '3.7.1'

set :application, 'backend'

set :deploy_to, '/var/www/backend-yalty/'

set :backend_service_name, 'app-02'
set :worker_service_name, 'app-03'

set :linked_dirs, %w(
  log
  tmp/pids
)

set :tasks_before_migration, %w(
)
set :tasks_after_migration, %w(
)

set :docker_roles, %w(api launchpad worker)
set :docker_repository, 'yalty/backend'
set :docker_source, '/code'
append :local_exclude_list, %w(
  .docker*
  .gitignore
  /public
  /spec
  /log
)

set :rbenv_roles, %w(api launchpad worker)
set :rbenv_path, -> { File.join(fetch(:deploy_to), 'rbenv') }
set :rbenv_map_bins, %w{ruby gem bundle}
set :bundle_map_bins, %w(rake rails)

set :keep_releases, 5
