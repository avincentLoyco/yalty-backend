lock '3.8.0'

set :application, 'backend'

set :deploy_to, '/var/www/backend-yalty/'

set :backend_service_name, 'app-02'
set :worker_service_name, 'app-03'

set :linked_dirs, %w(
  files
  log
  tmp/pids
)

set :maintenance_mode, false

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
