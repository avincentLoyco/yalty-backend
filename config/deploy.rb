lock '3.7.0'

set :application, 'backend'

set :docker_roles, %w(api launchpad worker db)

set :docker_repository, 'yalty/backend'
set :docker_source, '/code'

ask :docker_tag, 'stable'

set :deploy_to, '/var/www/backend-yalty/'

append :local_exclude_list, %w(.docker* .gitignore public)

set :keep_releases, 5
