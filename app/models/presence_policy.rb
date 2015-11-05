class PresencePolicy < ActiveRecord::Base
  has_many :employees
  has_many :working_places
  has_many :presence_days
  belongs_to :account

  validates :account_id, :name, presence: true
end
