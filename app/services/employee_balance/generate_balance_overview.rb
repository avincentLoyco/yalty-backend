class GenerateBalanceOverview

def initialize(employee_id)
  @employee = Employee.find(employee_id)
  @active_categories = @employee.employee_time_off_policies.pluck(:time_off_category_id).uniq
  @current_etop_per_category =
  @next_etop_per_category =
end


def call

end

def find_current_etop_per_category
  categories_hash = {}
  @active_categories.map do |category_id|
    categories_hash[:categories_hash] =
      employee.assigned_time_off_policies_in_category(category_id).first
  end
end

def find_next_etop_per_category
  @next_etop
end

{
  current_policy: ,
  start_date_of_period: ,
  end_date_of_period: ,
  validity_date_of_period: ,
}
