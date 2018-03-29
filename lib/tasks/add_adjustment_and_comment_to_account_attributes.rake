desc "Add adjustment and comment to account attributes"
task add_adjustment_and_comment_to_account_attributes: :environment do
  Account.find_each(&:update_default_attribute_definitions!)
end
