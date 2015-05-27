class AddCompanyNameToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :company_name, :string
  end
end
