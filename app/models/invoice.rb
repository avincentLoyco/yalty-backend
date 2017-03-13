class Invoice < ActiveRecord::Base
  serialize :address, Payments::CompanyInformation
  serialize :invoice_items, Payments::InvoiceItems

  belongs_to :account
  validates :total_payed_amount, :status, :date, presence: true
end
