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
    allow_blank: true
  validates :postalcode,
    length: { maximum: 12 },
    format: { with: /\A[A-Z0-9 -]+\z/, message: 'only numbers, capital letters and -'},
    allow_blank: true
  validates :street_number,
    length: { maximum: 10 },
    format: { with: /\A[A-Z0-9 \/]+\z/, message: 'only numbers, capital letters and /'},
    allow_blank: true
  validate :address_existance, on: [:create, :update], if: [:city, :country]
  validate :correct_address, on: [:create, :update], if: [:city, :country]
  after_validation :assign_address, on: [:create, :update], if: [:city, :country]

  scope :active_for_employee, lambda { |employee_id, date|
    joins(:employee_working_places)
      .where("employee_working_places.employee_id= ? AND
              employee_working_places.effective_at <= ?", employee_id, date)
      .order('employee_working_places.effective_at desc')
      .first
  }

  private

  def place_info
    @place_info ||= Geokit::Geocoders::GoogleGeocoder.geocode("#{city}, #{country}")
  end

  def place_timezone
    @place_timezone ||= Timezone.lookup(place_info.lat, place_info.lng).name
  end

  def address_existance
    return if place_info.city.present? || place_info.country.present?
    errors.add(:address, 'place does not exist')
  end

  def correct_address
    return if standardized_city == capitalized_city && standardized_country == capitalized_country
    errors.add(:address, 'place not found')
  end

  def assign_address
    self.city = place_info.city
    self.country = place_info.country
    self.timezone = place_timezone
  end

  def standardized_city
    return if place_info.city.nil?
    I18n.transliterate(place_info.city).downcase.capitalize
  end

  def standardized_country
    return if place_info.country.nil?
    I18n.transliterate(place_info.country).downcase.capitalize
  end

  def capitalized_city
    I18n.transliterate(city).downcase.capitalize
  end

  def capitalized_country
    I18n.transliterate(country).downcase.capitalize
  end
end
