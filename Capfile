require 'capistrano/setup'
require 'capistrano/deploy'
# require 'new_relic/recipes'

# Load the SCM plugin appropriate to your project:
require 'capistrano/docker_copy'
install_plugin Capistrano::DockerCopy

# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
