class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places, required: true
  belongs_to :holiday_policy
  belongs_to :presence_policy
  has_many :employees, inverse_of: :working_place

  validates :name, :account_id, presence: true
end
