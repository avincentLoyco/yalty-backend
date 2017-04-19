class Invoice < ActiveRecord::Base
  POSSIBLE_STATUSES = %w(pending failed success).freeze
  TAX_PERCENT = 8.0

  serialize :address, Payments::CompanyInformation
  serialize :lines, Payments::InvoiceLines

  belongs_to :account
  has_one :generic_file, as: :fileable
  validates :invoice_id, :status, :date, :amount_due, presence: true
  validates :status, inclusion: { in: POSSIBLE_STATUSES }
end
