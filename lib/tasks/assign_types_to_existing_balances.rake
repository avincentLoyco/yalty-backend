namespace :assign_types_to_existing_balances do
  task update: :environment do
    # Set balance type for end_of_period, removal, reset and time_off
    Employee::Balance.where("extract(second from effective_at) = 1")
                     .update_all(balance_type: "end_of_period")
    Employee::Balance.where("extract(second from effective_at) = 3")
                     .update_all(balance_type: "removal")
    Employee::Balance.where.not(time_off_id: nil)
                     .update_all(balance_type: "time_off")
    Employee::Balance.where(reset_balance: true)
                     .update_all(balance_type: "reset")

    # Destroy not used removal balances
    Employee::Balance.includes(:balance_credit_additions)
                     .where(balance_type: "removal")
                     .where(balance_credit_additions_employee_balances: {
                              balance_credit_removal_id: nil
                            })
                     .destroy_all

    # Set balance type for assignation and addition (first to assignation, then fix additions)
    Employee::Balance.where("extract(second from effective_at) = 2")
                     .update_all(balance_type: "assignation")

    count = Employee::Balance.where(balance_type: "assignation")
                             .where(policy_credit_addition: true)
                             .count
    Employee::Balance.where(balance_type: "assignation")
                     .where(policy_credit_addition: true)
                     .find_each.with_index do |balance, index|
      puts "migrate #{balance.id} (#{index + 1} / #{count})"
      create_or_assign_addition(balance)
      balance.save!
    end
  end

  def create_or_assign_addition(balance)
    if balance.employee_time_off_policy.effective_at.eql?(balance.effective_at.to_date)
      balance.resource_amount = 0
      balance.policy_credit_addition = false
      result = create_addition_balance(balance)
      puts "create #{result.id}"
    else
      balance.balance_type = "addition"
    end
  end

  def create_addition_balance(balance)
    etop = balance.employee_time_off_policy
    effective_at = balance.effective_at.beginning_of_day + 5.seconds
    validity_date = RelatedPolicyPeriod.new(etop).validity_date_for_balance_at(effective_at)
    validity_date =
      validity_date ? validity_date.to_date + 1.day + Employee::Balance::REMOVAL_OFFSET : nil

    Employee::Balance.create!(
      resource_amount: etop.time_off_policy.amount.to_i,
      effective_at: effective_at,
      time_off_category: balance.time_off_category,
      employee: balance.employee,
      validity_date: validity_date,
      balance_type: "addition"
    )
  end
end
