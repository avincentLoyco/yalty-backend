class Invoice < ActiveRecord::Base
  POSSIBLE_STATUSES = %w(pending failed success).freeze

  serialize :address, Payments::CompanyInformation
  serialize :lines, Payments::InvoiceLines

  belongs_to :account
  validates :status, :date, :amount_due, presence: true
  validates :status, inclusion: { in: POSSIBLE_STATUSES }
end
