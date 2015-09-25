class WorkingPlace < ActiveRecord::Base
  belongs_to :account, inverse_of: :working_places
  has_many :employees, inverse_of: :working_place

  validates :name, presence: true
end
