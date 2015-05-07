class Account < ActiveRecord::Base
  validates :subdomain, presence: true,
                        uniqueness: { case_sensitive: false },
                        format: { with: /\A[0-9a-z][0-9a-z\-]+[0-9a-z]\z/, allow_blank: true }
  validates :company_name, presence: true
end
