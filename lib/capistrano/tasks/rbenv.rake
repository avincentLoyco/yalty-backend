namespace :rbenv do
  task :install_rbenv do
    on release_roles(fetch(:rbenv_roles)) do
      next if test "[ -d #{fetch(:rbenv_path)} ]"
      execute :git, :clone, "https://github.com/rbenv/rbenv.git", fetch(:rbenv_path)
    end
  end

  task :install_ruby_build do
    rbenv_ruby_build_path = File.join(fetch(:rbenv_path), "plugins", "ruby-build")

    on release_roles(fetch(:rbenv_roles)) do
      next if test "[ -d #{rbenv_ruby_build_path} ]"
      execute :git, :clone, "https://github.com/sstephenson/ruby-build.git", rbenv_ruby_build_path
    end
  end

  task :install_ruby do
    rbenv_ruby_build_path = File.join(fetch(:rbenv_path), "plugins", "ruby-build")

    on release_roles(fetch(:rbenv_roles)) do
      next if test "[ -d #{fetch(:rbenv_ruby_dir)} ]"

      within rbenv_ruby_build_path do
        execute :git, :pull
      end
      execute "#{fetch(:rbenv_path)}/bin/rbenv", :install, fetch(:rbenv_ruby)
    end
  end

  task install_bundler: [:'rbenv:map_bins'] do
    on release_roles(fetch(:rbenv_roles)) do
      bundler_version = fetch(:rbenv_bundler)
      local_gem_path = File.join(fetch(:local_temporary_root), "bundler-#{bundler_version}.gem")
      remote_gem_path = File.join(fetch(:remote_temporary_root), "bundler-#{bundler_version}.gem")

      next if test(
        :gem, :query,
        "--quiet --installed --name-matches ^bundler$ -v #{bundler_version}"
      )

      run_locally do
        execute "mkdir -p #{fetch(:local_temporary_root)}"
        execute "cd #{fetch(:local_temporary_root)}; gem fetch bundler -v #{bundler_version}"
      end

      execute :mkdir, "-p", fetch(:remote_temporary_root)
      upload! local_gem_path, fetch(:remote_temporary_root)
      execute :gem, :install, "--force --local --quiet --no-rdoc --no-ri", remote_gem_path
    end
  end

  desc "Run rbenv rehash command"
  task rehash: [:'rbenv:install'] do
    on release_roles(fetch(:rbenv_roles)) do
      execute :rbenv, :rehash
    end
  end

  task :map_bins do
    SSHKit.config.default_env.merge!(
      rbenv_root: fetch(:rbenv_path),
      rbenv_version: fetch(:rbenv_ruby)
    )
    SSHKit.config.command_map[:rbenv] = "#{fetch(:rbenv_path)}/bin/rbenv"

    rbenv_prefix = fetch(:rbenv_prefix, proc { "#{fetch(:rbenv_path)}/bin/rbenv exec" })
    fetch(:rbenv_map_bins).each do |command|
      SSHKit.config.command_map.prefix[command.to_sym].unshift(rbenv_prefix)
    end
    fetch(:bundle_map_bins).each do |command|
      SSHKit.config.command_map.prefix[command.to_sym].unshift("bundle exec")
      SSHKit.config.command_map.prefix[command.to_sym].unshift(rbenv_prefix)
    end
  end

  desc "Install rbenv ruby"
  task :install do
    invoke "rbenv:install_rbenv"
    invoke "rbenv:install_ruby_build"
    invoke "rbenv:install_ruby"
    invoke "rbenv:install_bundler"
  end

  before "deploy:publishing", "rbenv:rehash"
end

Capistrano::DSL.stages.each do |stage|
  after stage, "rbenv:install"
  after stage, "rbenv:map_bins"
end

namespace :load do
  task :defaults do
    set :rbenv_ruby_dir, -> { "#{fetch(:rbenv_path)}/versions/#{fetch(:rbenv_ruby)}" }
  end
end
