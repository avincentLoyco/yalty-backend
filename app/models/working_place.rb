class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places, required: true
  belongs_to :holiday_policy
  belongs_to :presence_policy
  has_many :employees, inverse_of: :working_place
  has_many :working_place_time_off_policies
  has_many :time_off_policies, through: :working_place_time_off_policies

  validates :name, :account_id, presence: true

  def active_time_off_policy_in_category(category_id)
    time_off_policies_in_category(category_id).first.try(:time_off_policy)
  end

  def previous_time_off_policy_in_category(category_id)
    time_off_policies_in_category(category_id).second.try(:time_off_policy)
  end

  private

  def time_off_policies_in_category(category_id)
    working_place_time_off_policies.assigned
                                   .joins(:time_off_policy)
                                   .where(time_off_policies:
                                              { time_off_category_id: category_id }
                                         )
                                   .order(effective_at: :desc)
  end
end
