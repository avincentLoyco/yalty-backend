class Employee::Attribute < ActiveRecord::Base
  self.primary_key = 'id'

  private

  def readonly?
    true
  end
end
