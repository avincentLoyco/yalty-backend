lock '3.7.1'

set :application, 'backend'

set :docker_roles, %w(api launchpad worker)
set :docker_repository, 'yalty/backend'
set :docker_source, '/code'
ask :docker_tag, 'stable'

set :deploy_to, '/var/www/backend-yalty/'

append :local_exclude_list, %w(
  .docker*
  .gitignore
  /public
  /spec
  /log
)

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

set :keep_releases, 5
