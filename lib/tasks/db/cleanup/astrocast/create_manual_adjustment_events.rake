namespace :db do
  namespace :cleanup do
    namespace :astrocast do
      desc "Create manual adjustment events for employees with missing balances"
      task create_manual_adjustment_events: [:environment] do
        class CreateManualAdjustmentForAstrocastEmployee
          def initialize(account, email)
            @account = account
            @email = email
          end

          def call
            params = {
              effective_at: Time.current,
              event_type: "adjustment_of_balances",
              employee: {
                id: employee.id,
                manager_id: nil,
              },
              employee_attributes: [
                {
                  attribute_name: "adjustment",
                  value: adjustment_value,
                },
              ],
            }

            Events::Adjustment::Create.new(params).call
            puts "Manual adjustment for #{@email} with value: #{adjustment_value} added"
          end

          private

          def employee
            @employee ||= @account.users.find_by!(email: @email).employee
          end

          def first_employee_time_off_policy
            employee.employee_time_off_policies
              .joins(:time_off_category)
              .merge(TimeOffCategory.vacation)
              .order("effective_at asc")
              .first
          end

          def adjustment_value
            @adjustment_value ||=
              first_employee_time_off_policy.time_off_policy.amount
          end
        end
        # end of CreateManualAdjustmentForAstrocastEmployee class

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
            CreateManualAdjustmentForAstrocastEmployee
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
