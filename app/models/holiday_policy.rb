class HolidayPolicy < ActiveRecord::Base
  belongs_to :account
  validates :name, presence: true
  validates :country, inclusion: { in: :countries, allow_nil: true }
  validates :region, inclusion: { in: :regions, allow_nil: true}
  validates :country, presence: :true, if: :region

  before_validation :downcase, if: :local_data?

  private

  def local_data?
    country || region
  end

  def downcase
    self[:country] = self[:country].try(:downcase)
    self[:region] = self[:region].try(:downcase)
  end

  def countries
    countries = []
    ISO3166::Country.translations.select { |key, value| countries.push(key.downcase) }
    countries
  end

  def regions
    regions = []
    if country && countries.include?(country)
      ISO3166::Country.new(country).states.select { |key, value| regions.push(key.downcase) }
    end
    regions
  end
end
