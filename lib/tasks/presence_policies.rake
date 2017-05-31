namespace :presence_policies do
  desc 'Update presence policies to have seven presence days assigned, updates balances if needed'
  task add_missing_days: :environment do
    ActiveRecord::Base.transaction do
      not_seven_days_policies.map do |policy|
        missing_days_for_policy = (1..7).to_a - policy.presence_days.pluck(:order)
        create_missing_days(policy, missing_days_for_policy)

        next if policy.employee_presence_policies.empty? || !missing_days_for_policy.include?(7)
        policy.employee_presence_policies.group_by { |epp| epp[:employee_id] }.map do |k, v|
          update_employee_balances_after_effective_at(k, v)
        end
      end
    end
  end

  def not_seven_days_policies
    PresencePolicy
      .joins(:presence_days)
      .group('presence_policies.id')
      .having('count(presence_days.id) != 7')
  end

  def create_missing_days(policy, missing_days_order)
    missing_days_order.each { |order| policy.presence_days.create!(order: order) }
  end

  def update_employee_balances_after_effective_at(employee_id, epps)
    grouped_balances_after_epp_effective_at(employee_id, epps.first).map do |_k, v|
      PrepareEmployeeBalancesToUpdate.new(v.first, update_all: true).call
      UpdateBalanceJob.perform_later(v.first.id, update_all: true)
    end
  end

  def grouped_balances_after_epp_effective_at(employee_id, epp)
    Employee
      .find(employee_id)
      .employee_balances
      .where('effective_at >= ?', epp.effective_at)
      .order(:effective_at)
      .group_by { |balance| balance[:time_off_category_id] }
  end
end
