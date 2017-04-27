class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places, required: true
  belongs_to :holiday_policy
  belongs_to :presence_policy
  has_many :employee_working_places
  has_many :employees, through: :employee_working_places

  validates :name, :account_id, presence: true
  validates :country_code, :city, :additional_address, length: { maximum: 60 }
  validates :street, length: { maximum: 72 }
  validates :state_code,
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
  validate :correct_address, if: [:coordinate_changed?, :coordinate?]
  validate :correct_state, if: [:coordinate_changed?, :coordinate?]
  validate :correct_country, if: [:coordinate_changed?, :coordinate?]

  before_validation :assign_coordinate_related_attributes, if: :coordinate_changed?

  scope :not_reset, -> { where(reset: false) }
  scope :active_for_employee, lambda { |employee_id, date|
    joins(:employee_working_places)
      .where("employee_working_places.employee_id= ? AND
              employee_working_places.effective_at <= ?", employee_id, date)
      .order('employee_working_places.effective_at desc')
      .first
  }

  def coordinate?
    %w(city state_code country_code).any? { |attr| send(:"#{attr}?") }
  end

  def coordinate_changed?
    (changed_attributes.keys & %w(city state_code country_code)).present?
  end

  private

  def location_attributes
    @location_attributes ||=
      Geokit::Geocoders::GoogleGeocoder
      .geocode([city, state_code, country_code].compact.join(', '), language: 'en')
  end

  def location_timezone
    @location_timezone ||= Timezone.lookup(location_attributes.lat, location_attributes.lng)
  end

  def address_found?
    (!state_required? || location_attributes.state_code.present?) &&
      location_attributes.country_code.present?
  end

  def right_country?
    country_data?(country_code) &&
      country_data?(location_attributes.country_code) &&
      standardize(country_data(location_attributes.country_code).translations['en']).eql?(
        standardize(country_data(country_code).translations['en'])
      )
  end

  def state_required?
    HolidayPolicy.country_with_regions?(location_attributes.country_code)
  end

  def right_state?
    !state_required? || !state_code.present? || state == state_code ||
      country_data(location_attributes.country_code)&.states&.key?(state_code)
  end

  def correct_address
    errors.add(:address, 'not found') unless address_found? && right_country?
  end

  def correct_state
    errors.add(:state_code, 'does not match given address') unless right_state?
  end

  def correct_country
    errors.add(:country_code, 'does not exist') unless !country_code? || country_data?(country_code)
  end

  def assign_coordinate_related_attributes
    if address_found? && right_country? && right_state?
      self.state_code ||= location_attributes.state_code if state_required?
      self.state = location_attributes.state_name if state_code.present?
      self.country = location_attributes.country
      self.timezone = location_timezone.name
    else
      self.state = nil
      self.country = nil
      self.timezone = nil
    end
  end

  def standardize(address_param)
    I18n.transliterate(address_param).downcase.capitalize unless address_param.nil?
  end

  def country_data(country_code)
    return unless country_code.present?
    ISO3166::Country.find_country_by_alpha2(country_code) ||
      ISO3166::Country.find_country_by_translated_names(country_code)
  end

  def country_data?(country_code)
    country_data(country_code).present?
  end
end
