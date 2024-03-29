desc "Mark all existing time-offs as approved"
task update_time_offs: :environment do
  TimeOff.joins(:employee_balance)
    .update_all(approval_status: TimeOff.approval_statuses.fetch(:approved))
end
