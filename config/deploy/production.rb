server '10.128.101.11', roles: %w(api launchpad), primary: true
server '10.128.101.12', roles: %w(api launchpad)
server '10.128.103.11', roles: %w(worker),        primary: true
# server '10.128.103.12', roles: %w(worker)

set :docker_tag, -> {
  begin
    File.read(File.expand_path('../../VERSION', __dir__)).strip
  rescue
    'VERSION file cannot be read to select version to deploy'
  end
}
ask :docker_tag, fetch(:docker_tag)
