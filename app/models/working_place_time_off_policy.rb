class WorkingPlaceTimeOffPolicy < ActiveRecord::Base
  belongs_to :working_place
  belongs_to :time_off_policy
  belongs_to :time_off_category
  has_many :employees, through: :working_place

  validates :working_place_id, :time_off_policy_id, :effective_at, presence: true
  validates :time_off_policy_id, uniqueness: { scope: [:working_place_id, :effective_at] }

  before_create :add_category_id

  scope :not_assigned, -> { where(['effective_at > ?', Time.zone.today]) }
  scope :assigned, -> { where(['effective_at <= ?', Date.tomorrow]) }
  scope :assigned_at, -> (date) { where(['effective_at <= ?', date]) }

  scope :by_working_place_in_category, lambda { |working_place_id, category_id|
    joins(:time_off_policy)
      .where(time_off_policies:
            { time_off_category_id: category_id }, working_place_id: working_place_id
            )
      .order(effective_at: :desc)
  }

  private

  def add_category_id
    self.time_off_category_id = time_off_policy.time_off_category_id
  end

  def effective_at_newer_than_previous_start_date
    category_id = time_off_policy.time_off_category_id
    active_policy = working_place.active_time_off_policy_in_category(category_id)
    return unless active_policy &&
        working_place.previous_start_date(category_id) > effective_at.to_date
    errors.add(:effective_at, 'Must be after current policy previous perdiod start date')
  end
end
