namespace :db do
  desc 'Run database migrations'
  task :migrate do
    on fetch(:migration_server) do
      within release_path do
        info 'Run database migration'
        execute :rake, 'db:migrate'
      end
    end
  end

  desc 'Dump database'
  task :dump do
    on fetch(:migration_server) do
      uri = URI.parse(capture('echo $DATABASE_URL'))
      dump_path = fetch(:db_dump_path)

      with pgpassword: uri.password do
        info "Dump database backup to #{dump_path}"

        execute :mkdir, '-p', File.dirname(dump_path)
        execute :pg_dump, '--format=c --clean --if-exists --no-owner --no-privileges',
          "--dbname #{uri.path[1..-1]}",
          "-h #{uri.host} -p #{uri.port}",
          "-U #{uri.user}",
          "--file #{dump_path}"
      end
    end
  end

  desc 'Dowload a database dump'
  task :download do
    invoke 'db:dump'

    on fetch(:migration_server) do
      local_path = "tmp/dump.#{fetch(:stage)}.pgsql"
      info "Download database dump to #{local_path}"
      download! fetch(:db_dump_path), local_path
    end
  end
end
