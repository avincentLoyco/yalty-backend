class User < ActiveRecord::Base
  has_secure_password

  validates :email, presence: true
  validates :password, length: { in: 8..74 }

  belongs_to :account, inverse_of: :users, required: true
end
