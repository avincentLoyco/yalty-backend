namespace :release do
  desc 'Create release candidate to deploy on staging environment'
  task candidate: [:staging] do
    version = fetch(:release_candidate_version)
    version_file = fetch(:version_file, File.expand_path('../../../VERSION', __dir__))

    run_locally do
      info 'Create release branch'
      execute :git, :checkout, '-b', "releases/#{version}"

      info 'Update VERSION file'
      File.write(version_file, version)

      info 'Push release candidate on git'
      execute :git, :add, version_file
      execute :git, :commit, "-m \"Create release candidate #{version}\""
      execute :git, :push, "-u origin releases/#{version}"

      info 'Wait on docker build, then deploy to staging environment:
        cap staging deploy'
    end
  end

  desc 'Approve last release candidate to deploy on production environment'
  task approve: [:production] do
    version = fetch(:app_version)
    sha1 = fetch(:app_version_sha1)

    run_locally do
      info 'Create release tag'
      execute :docker, :pull, "yalty/backend:#{version}-rc-#{sha1}"
      execute :docker, :tag, "yalty/backend:#{version}-rc-#{sha1}", "yalty/backend:#{version}"
      execute :git, :tag, "v#{version}", sha1
      execute :docker, :push, "yalty/backend:#{version}"
      execute :git, :push, '--tags'

      info 'Deploy to production environment:
        cap production deploy'
    end
  end
end
