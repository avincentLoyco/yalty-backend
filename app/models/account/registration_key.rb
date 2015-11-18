class Account::RegistrationKey < ActiveRecord::Base
  belongs_to :account

  validates :token, presence: true, uniqueness: true
  before_validation :generate_token, on: :create

  scope :unused, -> { where('account_id IS NULL') }

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(16)
  end
end
