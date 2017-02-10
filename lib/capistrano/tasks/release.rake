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

      info 'Wait on docker build and deploy to staging environment:
        cap staging deploy'
    end
  end

  desc 'Finalize release to deploy on production environment'
  task finalize: [:production] do
    version = fetch(:app_version)

    run_locally do
      info 'Create release tag'
      execute :docker, :pull, "yalty/backend:#{version}-rc"
      execute :docker, :tag, "yalty/backend:#{version}-rc", "yalty/backend:#{version}"
      execute :git, :tag, "v#{version}"
      execute :docker, :push, "yalty/backend:#{version}"
      execute :git, :push, '--tags'

      info 'Create a backup of production database:
         pg_dump --format=c --clean --if-exists --no-owner --no-privileges --dbname yaltydb \
         -h 10.128.104.10 -p 5432 -U postgres -W --file dump.pgsql'

      info 'Then deploy to production environment:
        cap production deploy'
    end
  end
end
