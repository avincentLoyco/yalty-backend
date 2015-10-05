class Holiday < ActiveRecord::Base
  belongs_to :holiday_policy

  validates :name, :date, :holiday_policy_id, presence: true
end
