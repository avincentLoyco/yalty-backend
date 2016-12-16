lock '3.7.0'

set :application, 'backend'

set :docker_roles, %w(api launchpad worker db)
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

set :rbenv_roles, %w(api launchpad worker db)
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
set :rbenv_map_bins, %w{gem bundle ruby}

set :keep_releases, 5
