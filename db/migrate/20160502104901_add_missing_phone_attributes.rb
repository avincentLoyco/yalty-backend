class AddMissingPhoneAttributes < ActiveRecord::Migration
  def up
    Account.all.each do |account|
      account.update_default_attribute_definitions!
    end
  end

  def down
  end
end
