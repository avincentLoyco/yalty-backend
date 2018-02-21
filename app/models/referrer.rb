class Referrer < ActiveRecord::Base
  InvalidToken = Class.new(StandardError)
  TOKEN_LENGTH = 4

  has_many :users, class_name: "Account::User", primary_key: :email, foreign_key: :email
  has_many :referred_accounts, class_name: "Account", primary_key: :token, foreign_key: :referred_by

  before_validation :assign_token, unless: :token

  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/ }
  validates :token, presence: true, uniqueness: true

  scope(:with_referred_accounts_count, lambda do |from = nil, to = nil|
    from = Time.zone.parse("1920-01-01").beginning_of_day unless from.present?
    to = Time.zone.now.end_of_day unless to.present?

    Referrer.select("referrers.*, (
        SELECT COUNT(accounts.*) FROM accounts
        WHERE accounts.referred_by = referrers.token
        AND (accounts.created_at::date BETWEEN '#{from}'::date AND '#{to}'::date)
      ) AS referred_accounts_count")
  end)

  private

  def assign_token
    new_token = nil

    3.times do |iterator|
      raise InvalidToken, "Reached maximum number of regenerations." if iterator == 2
      new_token = SecureRandom.hex(TOKEN_LENGTH)
      break if Referrer.where(token: new_token).empty?
    end

    self.token = new_token
  end
end
