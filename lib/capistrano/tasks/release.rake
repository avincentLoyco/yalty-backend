namespace :release do
  desc "Create release candidate to deploy on staging environment"
  task candidate: [:staging] do
    version = fetch(:release_candidate_version)
    version_file = fetch(:version_file, File.expand_path("../../../VERSION", __dir__))

    run_locally do
      info "Create release branch"
      execute :git, :checkout, "-b", "releases/#{version}"

      info "Update VERSION file"
      File.write(version_file, version)

      info "Push release candidate on git"
      execute :git, :add, version_file
      execute :git, :commit, "-m \"Create release candidate #{version}\""
      execute :git, :push, "-u origin releases/#{version}"
      execute :hub, :'pull-request', "--browse",
        "-m \"Release #{version}\" -b yalty:master -h yalty:releases/#{version}",
        raise_on_non_zero_exit: true ||
          "hub extension for git is not installed, create Pull Request manually"

      info 'Wait on docker build, then deploy to staging environment:
        cap staging deploy'
    end
  end

  desc "Approve last release candidate to deploy on production environment"
  task approve: [:production] do
    version = fetch(:app_version)
    sha1 = fetch(:app_version_sha1)

    tasks_file = File.expand_path("../../../config/deploy/tasks.json", __dir__)
    tasks_json = JSON.parse(File.read(tasks_file))
    tasks_json["before_migration"].clear
    tasks_json["after_migration"].clear

    run_locally do
      info "Create release tag"
      execute :docker, :pull, "yalty/backend:#{version}-rc-#{sha1}"
      execute :docker, :tag, "yalty/backend:#{version}-rc-#{sha1}", "yalty/backend:#{version}"
      execute :git, :tag, "v#{version}", sha1
      execute :docker, :push, "yalty/backend:#{version}"
      execute :git, :push, "--tags"

      info "Cleanup tasks list"
      File.write(tasks_file, JSON.pretty_generate(tasks_json))
      if test "git diff-index --ignore-space-change --quiet v#{version} -- #{tasks_file}"
        info "nothing to do..."
      else
        execute :git, :add, tasks_file
        execute :git, :commit, '-m "Cleanup list of deploy tasks"'
        execute :git, :push, "-u origin releases/#{version}"
      end

      info 'Deploy to production environment:
        cap production deploy'
    end
  end
end
