class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places, required: true
  belongs_to :holiday_policy
  belongs_to :presence_policy
  has_many :employee_working_places
  has_many :employees, through: :employee_working_places

  validates :name, :account_id, presence: true

  scope :active_for_employee, lambda { |employee_id, date|
    joins(:employee_working_places)
      .where("employee_working_places.employee_id= ? AND
              employee_working_places.effective_at <= ?", employee_id, date)
      .order('employee_working_places.effective_at desc')
      .first
  }

end
