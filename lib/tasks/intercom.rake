namespace :intercom do
  desc 'import users to intercom'
  task :import => [:environment] do
    Account.all.each do |account|
      puts "import  #{account.company_name}"
      account.create_or_update_on_intercom(true)

      account.users.each do |user|
        puts "import #{user.email}"
        user.create_or_update_on_intercom(true)
      end

      puts ''
    end
  end
end
