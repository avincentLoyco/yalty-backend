class TimeOffCategory < ActiveRecord::Base
  belongs_to :account
  has_many :time_offs

  validates :account, :name, presence: true
end
