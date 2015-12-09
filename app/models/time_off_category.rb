class TimeOffCategory < ActiveRecord::Base
  belongs_to :account

  validates :account, :name, presence: true
end
