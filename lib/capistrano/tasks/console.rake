namespace :console do
  desc 'Open remote rails console'
  task :rails do
    server = fetch(:running_console_server)
    puts 'WARNING: You connect to a remote rails console'
    exec "ssh #{server.hostname} -t 'cd #{current_path} && bundle exec rails console'"
  end

  desc 'Interact with a remote rails dbconsole'
  task :database do
    server = fetch(:running_console_server)
    puts 'WARNING: You connect to a remote database console'
    exec "ssh #{server.hostname} -t 'cd #{current_path} && bundle exec rails dbconsole -p'"
  end
end
