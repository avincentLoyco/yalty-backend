notification :tmux, display_message: true

guard :rspec, cmd: 'bin/rspec', failed_mode: :keep do
  require 'guard/rspec/dsl'
  dsl = Guard::RSpec::Dsl.new(self)

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper)
  watch(rspec.spec_support)
  watch(rspec.spec_files)
  watch(%r{spec/factories/.+\.rb$})

  # Ruby files
  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)

  # Rails files
  rails = dsl.rails(view_extensions: %w(erb))
  dsl.watch_spec_files_for(rails.app_files)
  # dsl.watch_spec_files_for(rails.views)

  watch(rails.controllers) do |m|
    [
      rspec.spec.call("routing/#{m[1]}_routing"),
      rspec.spec.call("controllers/#{m[1]}_controller"),
      # rspec.spec.call("acceptance/#{m[1]}")
    ]
  end

  watch(%r{^lib/tasks/(.+)\.rake$}) { |m| rspec.spec.call("lib/tasks/#{m[1]}") }

  # Rails config changes
  watch(rails.spec_helper)
  watch(rails.routes)
  watch(rails.app_controller)
end
