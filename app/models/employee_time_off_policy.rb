class EmployeeTimeOffPolicy < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_policy

  validates :employee_id, :time_off_policy_id, :effective_at, presence: true
  validates :time_off_policy_id, uniqueness: { scope: [:employee_id, :effective_at] }
  validate :effective_at_newer_than_previous_start_date, if: [:time_off_policy, :effective_at]

  scope :affected_employees, lambda { |policy_id|
    where(time_off_policy_id: policy_id).pluck(:employee_id)
  }

  scope :not_assigned, -> { where(['effective_at > ?', Date.today]) }
  scope :assigned, -> { where(['effective_at <= ?', Date.tomorrow]) }
  scope :by_employee_in_category, lambda { |employee_id, category_id|
    joins(:time_off_policy)
      .where(time_off_policies: { time_off_category_id: category_id }, employee_id: employee_id)
      .order(effective_at: :desc)
  }

  def policy_length
    time_off_policy.years_to_effect > 1 ? time_off_policy.years_to_effect : 1
  end

  def first_start_date
    start_year_date =
      Date.new(effective_at.year, time_off_policy.start_month, time_off_policy.start_day)
    effective_at > start_year_date ? start_year_date + 1.year : start_year_date
  end

  def last_start_date
    years_before = (Time.zone.today.year - first_start_date.year) % policy_length
    last_date =
      Date.new(
        Time.zone.today.year - years_before, time_off_policy.start_month, time_off_policy.start_day
      )

    last_date > Time.zone.today ? last_date - policy_length.years : last_date
  end

  def end_date
    if time_off_policy.end_day && time_off_policy.end_month
      Date.new(
        last_start_date.year + policy_length, time_off_policy.end_month, time_off_policy.end_day
      )
    else
      last_start_date + policy_length
    end
  end

  def previous_start_date
    policy_length > 1 ? last_start_date - policy_length.years : last_start_date - 1.year
  end

  def current_end_date
    if time_off_policy.end_day && time_off_policy.end_month
      Date.new(end_in_years, end_month, end_day)
    else
      last_start_date + time_off_policy.years_or_effect
    end
  end

  private

  def effective_at_newer_than_previous_start_date
    category_id = time_off_policy.time_off_category_id
    active_policy = employee.active_related_time_off_policy(category_id)
    return unless active_policy && active_policy.employee.previous_start_date(category_id) >
        effective_at.to_date
    errors.add(:effective_at, 'Must be after current policy previous perdiod start date')
  end
end
