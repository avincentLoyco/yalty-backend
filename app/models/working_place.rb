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
    format: { with: %r{\A([a-zA-Z0-9 \/]+\z)},
              message: 'only numbers, capital letters, spaces and /' },
    allow_nil: true
  validate :correct_address, if: :coordinate_changed?
  validate :correct_state, if: :coordinate_changed?
  validate :correct_country, if: :coordinate_changed?

  before_validation :assign_coordinate_related_attributes, if: :coordinate_changed?

  scope :active_for_employee, lambda { |employee_id, date|
    joins(:employee_working_places)
      .where("employee_working_places.employee_id= ? AND
              employee_working_places.effective_at <= ?", employee_id, date)
      .order('employee_working_places.effective_at desc')
      .first
  }

  def country_code
    country_data(country)&.alpha2&.downcase
  end

  def coordinate_changed?
    !(changed_attributes.keys & %w(city state country)).empty?
  end

  private

  def location_attributes
    @location_attributes ||=
      Geokit::Geocoders::GoogleGeocoder
      .geocode([city, state, country_code, country].compact.join(', '))
  end

  def location_timezone
    @location_timezone ||= Timezone.lookup(location_attributes.lat, location_attributes.lng)
  end

  def address_found?
    (!city.present? || location_attributes.city.present?) &&
      (!state_required? || location_attributes.state_code.present?) &&
      location_attributes.country.present?
  end

  def right_country?
    country_data(country).present? &&
      country_data(location_attributes.country).present? &&
      standardize(country_data(location_attributes.country).translations['en']).eql?(
        standardize(country_data(country).translations['en'])
      )
  end

  def state_required?
    HolidayPolicy::COUNTRIES_WITH_CODES.include?(location_attributes.country_code&.downcase)
  end

  def right_state?
    !state_required? || !state.present? ||
      location_attributes.state_code.casecmp(state).zero? ||
      location_attributes.state_name.casecmp(state).zero?
  end

  def correct_address
    errors.add(:address, 'not found') unless address_found? && right_country?
  end

  def correct_state
    errors.add(:state, 'does not match given address') unless right_state?
  end

  def correct_country
    errors.add(:country, 'does not exist') unless country_data(country).present?
  end

  def assign_coordinate_related_attributes
    return unless address_found? && right_country?

    self.state = location_attributes.state if state_required? && !state.present?
    self.state_code = location_attributes.state_code.downcase
    self.timezone = location_timezone.name
  end

  def standardize(address_param)
    I18n.transliterate(address_param).downcase.capitalize unless address_param.nil?
  end

  def country_data(country_name)
    ISO3166::Country.find_country_by_translated_names(country_name)
  end
end
