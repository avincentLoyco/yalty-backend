server '10.128.102.11', roles: %w(api launchpad worker), primary: true

# Docker tag
ask :docker_tag, proc {
  run_locally do
    branch = capture(:git, 'rev-parse --abbrev-ref HEAD')
    if branch.match?(/^releases?\/[\d\.]+$/)
      [fetch(:app_version), 'rc', fetch(:app_version_sha1)].join('-')
    else
      branch[/ywa-\d+/]
    end
  end
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
ask :active_subdomains, %w(yalty pika timecorps exemple1 exemple-2 test)

desc 'Sync database from tmp/dump.production.pgsql'
task :sync do
  raise 'Do not run this task outside of staging environment' unless fetch(:stage) == :staging

  dump_path = fetch(:db_dump_path)
  local_path = fetch(:local_database_dump_path)

  invoke 'stop:all'

  on fetch(:migration_server) do
    uri = URI.parse(capture('echo $DATABASE_URL'))

    with pgpassword: uri.password do
      within release_path do
        info "Restore database from #{local_path}"

        execute :mkdir, '-p', File.dirname(dump_path)
        execute :rake, 'db:drop', 'db:create'

        upload! local_path, dump_path

        execute :pg_restore, '--format=c --no-security-labels',
          "--dbname #{uri.path[1..-1]}",
          "-h #{uri.host} -p #{uri.port}",
          "-U #{uri.user}",
          dump_path
        execute :rake, :setup
        execute :rake, :'staging:reset:stripe'

        execute :rm, '-f', dump_path
      end
    end
  end

  run_locally do
    execute :rm, '-f', local_path
  end

  invoke 'start:all'
end
