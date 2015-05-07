class Account < ActiveRecord::Base
  validates :subdomain, presence: true, uniqueness: { case_sensitive: false }
  validates :company_name, presence: true
end
