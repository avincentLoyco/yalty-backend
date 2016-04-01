class WorkingPlaceTimeOffPolicy < ActiveRecord::Base
  include CalculateRelatedTimeOffPeriods

  belongs_to :working_place
  belongs_to :time_off_policy
  has_many :employees, through: :working_place

  validates :working_place_id, :time_off_policy_id, :effective_at, presence: true
  validates :time_off_policy_id, uniqueness: { scope: [:working_place_id, :effective_at] }
  validate :effective_at_newer_than_previous_start_date, if: [:time_off_policy, :effective_at]

  scope :not_assigned, -> { where(['effective_at > ?', Time.zone.today]) }
  scope :assigned, -> { where(['effective_at <= ?', Date.tomorrow]) }
  scope :assigned_at, -> (date) { where(['effective_at <= ?', date]) }

  scope :affected_employees, lambda { |policy_id|
    where(time_off_policy_id: policy_id).joins(:working_place)
      .joins(:employees).pluck(:'employees.id')
  }

  scope :by_working_place_in_category, lambda { |working_place_id, category_id|
    joins(:time_off_policy)
      .where(time_off_policies:
            { time_off_category_id: category_id }, working_place_id: working_place_id
            )
      .order(effective_at: :desc)
  }

  private

  def effective_at_newer_than_previous_start_date
    category_id = time_off_policy.time_off_category_id
    active_policy = working_place.active_time_off_policy_in_category(category_id)
    return unless active_policy && active_policy.previous_period.first > effective_at.to_date
    errors.add(:effective_at, 'Must be after current policy previous perdiod start date')
  end
end
