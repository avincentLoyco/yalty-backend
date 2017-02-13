server '10.128.102.11', roles: %w(api launchpad worker), primary: true

# Docker tag
ask :docker_tag, proc {
  [fetch(:app_version), 'rc', fetch(:app_version_sha1)].join('-')
}

# Application version
ask :release_candidate_version, proc {
  begin
    version = fetch(:app_version).split('.').map(&:to_i)
    version[-1] += 1
    version.join('.')
  rescue
    'VERSION file cannot be incremented'
  end
}
