class TimeOffPolicy < ActiveRecord::Base
  belongs_to :time_off_category
  has_many :employee_balances, class_name: 'Employee::Balance'
  has_many :employee_time_off_policies
  has_many :employees, through: :employee_time_off_policies
  has_many :working_place_time_off_policies
  has_many :working_places, through: :working_place_time_off_policies

  validates :start_day,
    :start_month,
    :end_day,
    :end_month,
    :policy_type,
    :time_off_category,
    presence: true
  validates :policy_type, inclusion: { in: %w(counter balance) }
  validates :years_to_effect, :years_passed, numericality: { greater_than_or_equal_to: 0 }

  scope :for_account_and_category, lambda { |account_id, time_off_category_id|
    joins(:time_off_category).where(
      time_off_categories: { account_id: account_id, id: time_off_category_id }
    )
  }
end
