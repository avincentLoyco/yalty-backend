require 'rails_helper'

RSpec.describe 'db:cleanup:create_missing_balances', type: :rake do
  include_context 'rake'
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  let(:user) { create(:account_user, role: 'account_administrator') }
  let(:account) { user.account }
  let!(:employee) { create(:employee, account: account) }
  let(:employee_id) { employee.id }
  let(:vacation_category) { create(:time_off_category, account: account, name: 'vacation_xsd') }

  let!(:task_path) { "lib/tasks/#{task_name.gsub(":", "/")}" }

  context 'when the policy is of type balancer' do
    let(:vacation_balancer_policy_amount) { 50 }
    let(:vacation_balancer_policy) do
      create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
        amount: vacation_balancer_policy_amount, years_to_effect: 1)
    end
    let!(:vacation_policy_assignation) do
      create(
        :employee_time_off_policy,
        employee: employee, effective_at: Time.zone.now,
        time_off_policy: vacation_balancer_policy
      )
    end

    context 'when there is an alternation between existing and non existing balances over the time ' do
      context 'when there is only one policy in the category' do
        before do
          addition_2016 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
            validity_date: DateTime.new(2017, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
            employee_id: employee_id
          )

          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_amount,
            effective_at: DateTime.new(2017, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
            balance_credit_additions: [addition_2016],
            employee_id: employee_id
          )
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(6) }
      end
      context 'when there is two policies in the category' do
        let(:extreme_vacations_balancer_policy) do
          create(:time_off_policy, :with_end_date, time_off_category: vacation_category,
            amount: vacation_balancer_policy_amount, years_to_effect: 1)
        end
        let!(:vacation_policy_assignation) do
          create(
            :employee_time_off_policy,
            employee: employee, effective_at: Time.zone.now - 1.year,
            time_off_policy: vacation_balancer_policy
          )
        end
        let!(:extreme_vacation_policy_assignation) do
          create(
            :employee_time_off_policy,
            employee: employee, effective_at: Time.zone.now,
            time_off_policy: extreme_vacations_balancer_policy
          )
        end
        before do
          addition_vacation_2015 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_amount,
            effective_at: DateTime.new(2015, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
            validity_date: DateTime.new(2016, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
            employee_id: employee_id
          )

          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_amount,
            effective_at: DateTime.new(2016, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
            balance_credit_additions: [addition_vacation_2015],
            employee_id: employee_id
          )
          addition_vacation_extreme_2016 = create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            resource_amount: vacation_balancer_policy_amount,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
            validity_date: DateTime.new(2017, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
            employee_id: employee_id
          )

          create(:employee_balance_manual,
            time_off_category: vacation_category,
            resource_amount: -vacation_balancer_policy_amount,
            effective_at: DateTime.new(2017, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
            balance_credit_additions: [addition_vacation_extreme_2016],
            employee_id: employee_id
          )
        end
        it { expect { subject }.to change { Employee::Balance.count }.by(6) }
      end
    end

    context 'when there are no existing balances ' do
      context 'when the missing assignation date' do
        context 'is the same as the start day of the policy' do
          let(:vacation_policy_assignation) do
            create(
              :employee_time_off_policy,
              employee: employee, effective_at: Time.zone.now - 2.days,
              time_off_policy: vacation_balancer_policy
            )
          end
          it { expect { subject }.to change { Employee::Balance.count }.by(10) }
        end
        context 'is different than the start day of the policy' do
          it { expect { subject }.to change { Employee::Balance.count }.by(8) }
        end
      end
    end


    context 'when there are no balances to be created' do
      before do
        addition_2016 = create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          resource_amount: vacation_balancer_policy_amount,
          effective_at: DateTime.new(2016, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
          validity_date: DateTime.new(2017, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          resource_amount: vacation_balancer_policy_amount,
          effective_at: DateTime.new(2016, 12, 31, 0, 0, 0) + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET,
          validity_date: DateTime.new(2017, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          employee_id: employee_id
        )

        create(:employee_balance_manual,
          time_off_category: vacation_category,
          resource_amount: -vacation_balancer_policy_amount,
          effective_at: DateTime.new(2017, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          balance_credit_additions: [addition_2016],
          employee_id: employee_id
        )
        addition_2017 = create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          resource_amount: vacation_balancer_policy_amount,
          effective_at: DateTime.new(2017, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
          validity_date: DateTime.new(2018, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          resource_amount: vacation_balancer_policy_amount,
          effective_at: DateTime.new(2017, 12, 31, 0, 0, 0) + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET,
          validity_date: DateTime.new(2018, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          employee_id: employee_id
        )

        create(:employee_balance_manual,
          time_off_category: vacation_category,
          resource_amount: -vacation_balancer_policy_amount,
          effective_at: DateTime.new(2018, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          balance_credit_additions: [addition_2017],
          employee_id: employee_id
        )
        addition_2018 = create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          resource_amount: vacation_balancer_policy_amount,
          effective_at: DateTime.new(2018, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
          validity_date: DateTime.new(2019, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          resource_amount: vacation_balancer_policy_amount,
          effective_at: DateTime.new(2018, 12, 31, 0, 0, 0) + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET,
          validity_date: DateTime.new(2019, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual,
          time_off_category: vacation_category,
          resource_amount: -vacation_balancer_policy_amount,
          effective_at: DateTime.new(2019, 4, 1, 0, 0, 0) + Employee::Balance::REMOVAL_OFFSET,
          balance_credit_additions: [addition_2018],
          employee_id: employee_id
        )
      end
      it { expect { subject }.to_not change { Employee::Balance.count } }
    end
  end
  context 'when the category has policies of type counter' do
    let(:vacation_counter_policy) do
      create(:time_off_policy, :as_counter, time_off_category: vacation_category, years_to_effect: 1)
    end
    let!(:vacation_policy_assignation) do
      create(
        :employee_time_off_policy,
        employee: employee, effective_at: Time.zone.now,
        time_off_policy: vacation_counter_policy
      )
    end

    context 'when there is an alternation between existing and non existing balances over the time ' do
      context 'when there is only one policy in the category' do
        before do
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
            employee_id: employee_id
          )
        end

        it { expect { subject }.to change { Employee::Balance.count }.by(4) }
      end
      context 'when there is two policies in the category' do
        let(:extreme_vacations_balancer_policy) do
          create(:time_off_policy, :as_counter, time_off_category: vacation_category,
                 years_to_effect: 1)
        end
        let!(:vacation_policy_assignation) do
          create(
            :employee_time_off_policy,
            employee: employee, effective_at: Time.zone.now - 1.year,
            time_off_policy: vacation_counter_policy
          )
        end
        let!(:extreme_vacation_policy_assignation) do
          create(
            :employee_time_off_policy,
            employee: employee, effective_at: Time.zone.now,
            time_off_policy: extreme_vacations_balancer_policy
          )
        end
        before do
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            effective_at: DateTime.new(2015, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
            employee_id: employee_id
          )
          create(:employee_balance_manual, :addition,
            time_off_category: vacation_category,
            effective_at: DateTime.new(2016, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
            employee_id: employee_id
          )
        end
        it { expect { subject }.to change { Employee::Balance.count }.by(4) }
      end
    end

    context 'when there are no existing balances' do
      context 'when the missing assignation date' do
        context 'is the same as the start day of the policy' do
          let(:vacation_policy_assignation) do
            create(
              :employee_time_off_policy,
              employee: employee, effective_at: Time.zone.now - 2.days,
              time_off_policy: vacation_counter_policy
            )
          end
          it { expect { subject }.to change { Employee::Balance.count }.by(7) }
        end
        context 'is different than the start day of the policy' do
          it { expect { subject }.to change { Employee::Balance.count }.by(5) }
        end
      end
    end

    context 'when there are no balances to be created' do
      before do
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          effective_at: DateTime.new(2016, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          effective_at: DateTime.new(2016, 12, 31, 0, 0, 0) + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          effective_at: DateTime.new(2017, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          effective_at: DateTime.new(2017, 12, 31, 0, 0, 0) + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          effective_at: DateTime.new(2018, 1, 1, 0, 0, 0) + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
          employee_id: employee_id
        )
        create(:employee_balance_manual, :addition,
          time_off_category: vacation_category,
          effective_at: DateTime.new(2018, 12, 31, 0, 0, 0) + Employee::Balance::DAY_BEFORE_START_DAY_OFFSET,
          employee_id: employee_id
        )
      end
      it { expect { subject }.to_not change { Employee::Balance.count } }
    end
  end
end
