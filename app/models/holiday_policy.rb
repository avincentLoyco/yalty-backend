class HolidayPolicy < ActiveRecord::Base
  belongs_to :account
  has_many :holidays
  has_many :working_places
  has_many :employees
  has_one :assigned_account, class_name: 'Account', foreign_key: :holiday_policy_id

  validates :name, presence: true
  validates :country, inclusion: { in: :countries, allow_nil: true }
  validates :region, inclusion: { in: :regions, allow_nil: true}, if: :valid_country?
  validates :country, presence: :true, if: :region
  before_validation :downcase, if: :is_local?

  private

  def is_local?
    country || region
  end

  def valid_country?
    country.present? && countries.include?(country)
  end

  def downcase
    self[:country] = country.try(:downcase)
    self[:region] = region.try(:downcase)
  end

  def countries
    ISO3166::Country.translations.keys.map &:downcase
  end

  def regions
    ISO3166::Country.new(country).states.keys.map &:downcase
  end
end
