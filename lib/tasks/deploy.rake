namespace :deploy do
  def options_for(target_env)
    options = Struct.new(:target_env, :scalingo_cmd, :branch, :remote, :ref, :user, :git_args).new

    options.target_env = target_env

    if target_env == 'production'
      options.remote = 'production'
      options.branch = 'stable'
    elsif target_env == 'staging'
      options.remote = 'staging'
      options.branch = 'master'
    else
      options.branch = `git rev-parse --abbrev-ref HEAD`.chomp
      options.remote = target_env
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

    unless system "git push #{options.git_args} #{options.remote} #{options.branch}:master"
      raise 'failing to deploy'
    end
  end

  def announce_deployment(options)
    newrelic_cmd = "newrelic deployments --revision=#{options.ref} --user=#{options.user}"
    system "#{options.scalingo_cmd} run \"#{newrelic_cmd}\""
  end

  def migrate_on(options)
    system "#{options.scalingo_cmd} run \"rake db:migrate\"" || raise('failing to migrate database')
    system "#{options.scalingo_cmd} restart" || puts('failing to restart')
  end

  # tasks
  ['production', 'staging', 'review'].each do |target_env|
    desc "Deploy to #{target_env} environment"
    task target_env => [:environment] do |task|
      options = options_for(target_env)
      deploy_to(options)
      migrate_on(options)
      announce_deployment(options)
    end
  end
end
