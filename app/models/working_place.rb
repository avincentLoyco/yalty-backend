class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places, required: true
  belongs_to :holiday_policy
  belongs_to :presence_policy
  has_many :employee_working_places
  has_many :employees, through: :employee_working_places

  validates :name, :account_id, :country, :city, presence: true
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
  validate :address_existance, on: [:create, :update], if: :address_presence?

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

  def address_presence?
    city.present? && country.present?
  end

  def address_existance
    if place_info.city.nil? || place_info.country.nil?
      errors.add(:address, 'place does not exist')
    else
      correct_address
    end
  end

  def correct_address
    return if standardized_city == capitalized_city && standardized_country == capitalized_country
    errors.add(:address, 'place not found')
  end

  def standardized_city
    @standardized_city ||= I18n.transliterate(place_info.city).downcase.capitalize
  end

  def standardized_country
    @standardized_country ||= I18n.transliterate(place_info.country).downcase.capitalize
  end

  def capitalized_city
    @capitalized_city ||= I18n.transliterate(city).downcase.capitalize
  end

  def capitalized_country
    @capitalized_country ||= I18n.transliterate(country).downcase.capitalize
  end
end
