namespace :db do
  namespace :cleanup do
    namespace :astrocast do
      require "create_manual_adjustment_for_employee"

      desc "Create manual adjustment events for employees with missing balances"
      task create_manual_adjustment_events: [:environment] do

        employee_emails = %w(
          fgeorge@astrocast.net
          jharris@astrocast.net
          jiseli@astrocast.com
          jjordan@astrocast.net
          kkarlsen@astrocast.net
          kowen@astrocast.net
          npetrig@astrocast.com
          sdeflorio@astrocast.com
          srossi@astrocast.net
        )

        account = Account.find_by!(subdomain: "astrocast")
        Account.current = account

        employee_emails.each do |email|
          begin
            CreateManualAdjustmentForEmployee
              .new(account, email)
              .call
          rescue StandardError => e
            puts e.message
          end
        end
      end
    end
  end
end
