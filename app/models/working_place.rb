class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places, required: true
  belongs_to :holiday_policy
  belongs_to :presence_policy
  has_many :employees, inverse_of: :working_place
  has_many :working_place_time_off_policies
  has_many :time_off_policies, through: :working_place_time_off_policies

  validates :name, :account_id, presence: true

  def time_off_policy_in_category(category_id)
    working_place_time_off_policies.joins(:time_off_policy)
                                   .find_by(time_off_policies:
                                              { time_off_category_id: category_id }
                                           )
                                   .try(:time_off_policy)
  end
end
