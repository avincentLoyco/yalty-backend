class Employee < ActiveRecord::Base
  attr_readonly :uuid

  belongs_to :account, inverse_of: :employees
end
