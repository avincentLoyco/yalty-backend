namespace :reset_resources do
  task create: :environment do
    Account.all.map do |account|
      account.create_reset_presence_policy_and_working_place!
      account.time_off_categories.map(&:create_reset_policy!)
    end
  end
end
