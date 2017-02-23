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

# Sync database with production dump
ask :local_database_dump_path, 'tmp/dump.production.pgsql'

desc 'Sync database from tmp/dump.production.pgsql'
task :sync do
  raise 'Do not run this task outside of staging environment' unless fetch(:stage) == :staging

  dump_path = fetch(:db_dump_path)
  local_path = fetch(:local_database_dump_path)

  on fetch(:migration_server) do
    uri = URI.parse(capture('echo $DATABASE_URL'))

    with pgpassword: uri.password do
      info "Restore database from #{local_path}"

      execute :mkdir, '-p', File.dirname(dump_path)
      upload! local_path, dump_path
      execute :pg_restore, '--format=c --clean --if-exists --no-owner --no-privileges',
        "--dbname #{uri.path[1..-1]}",
        "-h #{uri.host} -p #{uri.port}",
        "-U #{uri.user}",
        dump_path
      execute :rm, '-f', dump_path

      execute :rake, :setup
    end
  end

  run_locally do
    execute :rm, '-f', local_path
  end
end
