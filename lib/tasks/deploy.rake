namespace :deploy do
  DeployOptions = Struct.new(:scalingo_cmd, :branch, :remote, :ref, :user, :git_args)

  def options_for(target_env)
    options = DeployOptions.new
    options.remote = target_env

    if options.remote == 'production'
      options.branch = 'stable'
    elsif options.remote == 'staging'
      options.branch = 'master'
    else
      options.branch = `git rev-parse --abbrev-ref HEAD`.chomp
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

    system "git push #{options.git_args} #{options.remote} #{options.branch}:master" || fail
  end

  def announce_deployment(options)
    newrelic_cmd = "newrelic deployments --revision=#{options.ref} --user=#{options.user}"
    system "#{options.scalingo_cmd} run \"#{newrelic_cmd}\""
  end

  def migrate_on(options)
    system "#{options.scalingo_cmd} run \"rake db:migrate\"" || fail
    system "#{options.scalingo_cmd} restart"
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
end
