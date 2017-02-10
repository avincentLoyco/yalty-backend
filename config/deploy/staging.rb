server '10.128.102.11', roles: %w(api launchpad worker), primary: true

# Docker tag
set :docker_tag, -> {
  [fetch(:app_version), 'rc', fetch(:app_version_sha1)].join('-')
}
ask :docker_tag, fetch(:docker_tag)

# Application version
set :release_candidate_version, -> {
  begin
    version = fetch(:app_version).split('.').map(&:to_i)
    version[-1] += 1
    version.join('.')
  rescue
    'VERSION file cannot be incremented'
  end
}
ask :release_candidate_version, fetch(:release_candidate_version)
