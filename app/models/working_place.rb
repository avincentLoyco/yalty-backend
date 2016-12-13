class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places, required: true
  belongs_to :holiday_policy
  belongs_to :presence_policy
  has_many :employee_working_places
  has_many :employees, through: :employee_working_places

  validates :name, :account_id, presence: true
  validates :country, :city, :additional_address, length: { maximum: 60 }
  validates :street, length: { maximum: 72 }
  validates :state,
    length: { maximum: 60 },
    format: { with: /\A[\D]+\z/, message: 'only nondigit' },
    allow_nil: true
  validates :postalcode,
    length: { maximum: 12 },
    format: { with: /\A([A-Z0-9 -])\w+/, message: 'only numbers, capital letters, spaces and -' },
    allow_nil: true
  validates :street_number,
    length: { maximum: 10 },
    format: { with: %r{\A([A-Z0-9 \/])\w+}, \
              message: 'only numbers, capital letters, spaces and /' },
    allow_nil: true
  validate :correct_country, on: [:create, :update], if: [:city, :country]
  validate :correct_address, on: [:create, :update], if: [:city, :country]
  before_save :assign_params, on: [:create, :update], if: [:city, :country]

  scope :active_for_employee, lambda { |employee_id, date|
    joins(:employee_working_places)
      .where("employee_working_places.employee_id= ? AND
              employee_working_places.effective_at <= ?", employee_id, date)
      .order('employee_working_places.effective_at desc')
      .first
  }

  private

  def location_attributes
    @location_attributes ||= Geokit::Geocoders::GoogleGeocoder.geocode("#{city}, #{country}")
  end

  def location_timezone
    Timezone.lookup(location_attributes.lat, location_attributes.lng).name
  end

  def address_found?
    location_attributes.city.present? && location_attributes.country.present?
  end

  def correct_address
    errors.add(:address, 'not found') unless correct_standardized_address
  end

  def correct_country
    errors.add(:country, 'does not exist') if country_data.empty?
  end

  def correct_standardized_address
    return unless address_found? && country_data.any?
    standardize(location_attributes.country).eql? \
      standardize(country_data.first.translations['en'])
  end

  def assign_params
    self.timezone = location_timezone
    if HolidayPolicy::COUNTRIES_WITHOUT_REGIONS.include?(location_attributes.country_code.downcase)
      self.state = nil
    else
      self.state = location_attributes.state_code.downcase
    end
  end

  def standardize(address_param)
    I18n.transliterate(address_param).downcase.capitalize unless address_param.nil?
  end

  def country_data
    ISO3166::Country
      .all
      .select do |place|
        place.translated_names.include?(country.downcase.capitalize)
      end
  end
end
