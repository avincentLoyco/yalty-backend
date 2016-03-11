namespace :deploy do
  DeployOptions = Struct.new(:scalingo_cmd, :branch, :remote, :ref, :user, :git_args)

  def options_for(target_env, branch = nil)
    options = DeployOptions.new
    options.remote = target_env
    options.branch = branch || `git rev-parse --abbrev-ref HEAD`.chomp

    if options.remote == 'production' && options.branch != 'stable'
      raise "branch '#{options.branch}' can't be deploy to '#{options.remote}' environment"
    elsif options.remote == 'staging' && options.branch !~ %r{^(master)|(stable)|(release/[0-9\.]+)$}
      raise "branch '#{options.branch}' can't be deploy to '#{options.remote}' environment"
    elsif options.remote =~ /^(review)|(staging)$/
      options.git_args = '--force'
    end

    options.ref  = `git rev-parse #{options.branch}`.chomp
    options.user = `git config user.email`.chomp

    options.scalingo_cmd = "scalingo --remote #{options.remote}"

    options
  end

  def deploy_to(options)
    print "Deploy `#{options.branch}' branch to `#{options.remote}' environment... in "
    3.downto(1) do |count|
      print "#{count} "
      sleep 1.5
    end
    print "go\n"

    system "git push #{options.git_args} #{options.remote} #{options.branch}:master"
  end

  def announce_deployment(options)
    newrelic_cmd = "newrelic deployments --revision=#{options.ref} --user=#{options.user}"
    system "#{options.scalingo_cmd} run \"#{newrelic_cmd}\""
  end

  def migrate_on(options)
    system "#{options.scalingo_cmd} run \"rake db:migrate\"" || raise
    system "#{options.scalingo_cmd} restart"
  end

  def postgresql_for(target_env)
    pg_env = `scalingo -r #{target_env} env | grep SCALINGO_POSTGRESQL_URL=`

    if result = pg_env.match(/SCALINGO_POSTGRESQL_URL=(postgres:\/\/([^:]+):([^@]+)@[^\/]+\/(.+))/)
      {
        env:      target_env,
        url:      result[1],
        user:     result[2],
        password: result[3],
        database: result[4]
      }
    else
      raise "Cannot get database information for #{target_env}"
    end
  end

  def postgresql_tunnel_to(options)
    pid = spawn "scalingo -r #{options[:env]} db-tunnel --port 10000 #{options[:url]}"
    sleep 5
    pid
  end

  # tasks
  %w(production staging review).each do |target_env|
    desc "Deploy to #{target_env} environment"
    task target_env => [:environment] do
      options = options_for(target_env)
      deploy_to(options)
      migrate_on(options)
      announce_deployment(options)
    end
  end

  %w(staging review).each do |target_env|
    namespace target_env do
      desc "Reset #{target_env} environment with production code and data"
      task reset: [:environment] do
        options = options_for(target_env, 'stable')
        deploy_to(options)

        db_production = postgresql_for(:production)
        tunnel = postgresql_tunnel_to(db_production)
        puts 'dump production database'
        system "PGPASSWORD=#{db_production[:password]} pg_dump --clean --if-exists --no-acl --no-owner -n public -U #{db_production[:user]} -h 127.0.0.1 -p 10000 #{db_production[:database]} > tmp/sync_dump.sql"
        Process.kill('SIGTERM', tunnel)

        db_target = postgresql_for(target_env)
        tunnel = postgresql_tunnel_to(db_target)
        puts "load #{target_env} database"
        system "PGPASSWORD=#{db_target[:password]} psql --quiet -U #{db_target[:user]} -h 127.0.0.1 -p 10000 -d #{db_target[:database]} < tmp/sync_dump.sql"
        Process.kill('SIGTERM', tunnel)

        system "#{options.scalingo_cmd} run \"rake setup\"" || raise
      end
    end
  end
end
