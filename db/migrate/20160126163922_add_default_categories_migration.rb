class AddDefaultCategoriesMigration < ActiveRecord::Migration
  def up
    Account.all.each do |account|
      TimeOffCategory.update_default_account_categories(account)
    end
  end

  def down
  end
end
