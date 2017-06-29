class RenameCompanyInformationColumn < ActiveRecord::Migration
  def change
    rename_column :accounts, :invoice_company_info, :company_information
  end
end
