task change_time_off_policies_amount_from_nil_to_0: :environment do
  TimeOffPolicy.where(amount: nil).update_all(amount: 0)
end
