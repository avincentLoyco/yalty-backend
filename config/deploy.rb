lock '3.7.1'

set :application, 'backend'

set :docker_roles, %w(api launchpad worker)
set :docker_repository, 'yalty/backend'
set :docker_source, '/code'

set :deploy_to, '/var/www/backend-yalty/'
set :backend_service_name, 'app-02'
set :worker_service_name, 'app-03'

set :app_version, -> {
  begin
    File.read(File.expand_path('../VERSION', __dir__)).strip
  rescue
    'VERSION file cannot be read'
  end
}

append :local_exclude_list, %w(
  .docker*
  .gitignore
  /public
  /spec
  /log
)

set :pty, true

set :rbenv_roles, %w(api launchpad worker)
set :rbenv_path, -> {
  File.join(fetch(:deploy_to), 'rbenv')
}
set :rbenv_ruby, -> {
  path = File.expand_path('../Gemfile', __dir__)
  File.read(path).match(/ruby '([^']+)'/)[1]
}
set :rbenv_bundler, -> {
  path = File.expand_path('../Gemfile.lock', __dir__)
  File.read(path).match(/BUNDLED WITH\n(.+)/)[1].strip
}
set :rbenv_map_bins, %w{ruby gem bundle}
set :bundle_map_bins, %w(rake)

set :linked_dirs, %w(
  log
  tmp/pids
)

set :keep_releases, 5
