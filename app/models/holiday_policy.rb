class HolidayPolicy < ActiveRecord::Base
  belongs_to :account
  validates :name, presence: true
  validates :country, inclusion: { in: :countries, allow_nil: true }

  before_validation :downcase, if: :country

  private

  def downcase
    self[:country] = self[:country].downcase
  end

  def countries
    countries = []
    ISO3166::Country.translations.select { |key, value| countries.push(key.downcase) }
    countries
  end
end
