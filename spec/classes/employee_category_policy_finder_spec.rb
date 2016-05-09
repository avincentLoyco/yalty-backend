require 'rails_helper'

RSpec.describe EmployeeCategoryPolicyFinder do
  include_context 'shared_context_timecop_helper'
  let(:employee) { create(:employee) }
  let(:account) { employee.account }
  let(:working_place) { employee.employee_working_places.last.working_place }
  let(:no_etop_employee) { create(:employee , account: account, working_place: working_place) }
  let(:category) { create(:time_off_category, account: account) }
  let(:first_policy) do
    create(:time_off_policy, time_off_category: category, start_day: 1, start_month: 1)
  end
  let(:second_policy) do
    create(:time_off_policy, :as_counter, time_off_category: category, start_day: 10, start_month: 1)
  end
  let(:three_months_from_now) { Time.zone.today + 3.months }
  let!(:employee_time_off_policy) do
    create(:employee_time_off_policy,
      employee: employee,
      effective_at: Time.zone.today - 1.days,
      time_off_policy: second_policy
    )
  end
  let!(:working_place_time_off_policy) do
    create(:working_place_time_off_policy,
      working_place: working_place,
      effective_at: Time.zone.today - 1.days,
      time_off_policy: first_policy
    )
  end

  describe '#data_from_employees_with_working_place_policy_for_day_and_month' do

    context 'when the policy is the current active for the given date one and start day and month match' do
      subject do
        described_class
          .new(Time.zone.today)
          .data_from_employees_with_working_place_policy_for_day_and_month
      end
      xit 'returns the data of for the employees that have no policy through employee but have from working place' do
        expected_result =
          {
            employee_id: no_etop_employee.id,
            time_off_category_id: category.id,
            policy_type: first_policy.policy_type,
            end_day: first_policy.end_day,
            end_month: first_policy.end_month,
            amount: first_policy.amount.to_s,
            years_to_effect: first_policy.years_to_effect.to_s,
            years_passed: first_policy.years_passed.to_s,
            account_id: account.id
          }.with_indifferent_access
        expect(subject.first).to eq expected_result
        expect(subject.size).to eq 1
      end
    end

    context 'when the start day or month does not match the given date' do
      subject do
        described_class
          .new(Time.zone.today + 9.day)
          .data_from_employees_with_working_place_policy_for_day_and_month
      end

      xit { expect(subject.size).to eq 0 }
    end
  end

  describe '#data_from_employees_with_employee_policy_for_day_and_month' do

    context 'when the policy is the current active for the given date one and start day and month matches the given ones' do
      subject do
        described_class
          .new(Time.zone.today + 9.days)
          .data_from_employees_with_employee_policy_for_day_and_month
      end
      it 'returns the data of for the employees that have a employee time off policy' do
        expected_result =
          {
            employee_id: employee.id,
            time_off_category_id: category.id,
            policy_type: second_policy.policy_type,
            end_day: second_policy.end_day,
            end_month: second_policy.end_month,
            amount: second_policy.amount,
            years_to_effect: second_policy.years_to_effect.to_s,
            years_passed: second_policy.years_passed.to_s,
            account_id: account.id
          }.with_indifferent_access
        expect(subject.first).to eq expected_result
        expect(subject.size).to eq 1
      end
    end

    context 'when the start day or month does not match the given date' do
      subject do
        described_class
          .new(Time.zone.today)
          .data_from_employees_with_employee_policy_for_day_and_month
      end

      it { expect(subject.size).to eq 0 }
    end
  end

  context '' do
    let!(:employee_time_off_policy_before_close_future_) do
      create(:employee_time_off_policy,
        employee: employee,
        effective_at: three_months_from_now - 1.day,
        time_off_policy: second_policy
      )
    end
    let!(:working_place_time_off_policy_before_close_future_) do
      create(:working_place_time_off_policy,
        working_place: working_place,
        effective_at: three_months_from_now - 1.day,
        time_off_policy: first_policy
      )
    end
    let!(:employee_time_off_policy_in_close_future) do
      create(:employee_time_off_policy,
        employee: employee,
        effective_at: three_months_from_now,
        time_off_policy: first_policy
      )
    end
    let!(:working_place_time_off_policy_in_close_future) do
      create(:working_place_time_off_policy,
        working_place: working_place,
        effective_at: three_months_from_now,
        time_off_policy: second_policy
      )
    end
    let!(:employee_time_off_policy_after_close_future) do
      create(:employee_time_off_policy,
        employee: employee,
        effective_at: three_months_from_now + 1.day,
        time_off_policy: second_policy
      )
    end
    let!(:working_place_time_off_policy_after_close_future) do
      create(:working_place_time_off_policy,
        working_place: working_place,
        effective_at: three_months_from_now + 1.day,
        time_off_policy: first_policy
      )
    end

    describe '#data_from_employees_with_working_place_policy_with_previous_policy_of_different_type' do

      context 'when the previous policy type is different from the one starting on the given date' do
        subject do
          described_class
            .new(three_months_from_now)
            .data_from_employees_with_working_place_policy_with_previous_policy_of_different_type
        end
        xit 'returns the data of the employees that have no policy through employee but have from working place' do
          expected_result =
            {
              employee_id: no_etop_employee.id,
              time_off_category_id: category.id,
              account_id: account.id
            }.with_indifferent_access
          expect(subject.first).to eq expected_result
          expect(subject.size).to eq 1
        end
      end

      context 'when the effective_at does not match the given date' do
        subject do
          described_class
            .new(three_months_from_now + 5.day)
            .data_from_employees_with_working_place_policy_with_previous_policy_of_different_type
        end

        xit { expect(subject.size).to eq 0 }
      end

      context 'when the effective_at matches but there are no employee with previous policy' do
        subject do
          described_class
            .new(Time.zone.today - 1.day)
            .data_from_employees_with_working_place_policy_with_previous_policy_of_different_type
        end

        xit { expect(subject.size).to eq 0 }

        context 'with different  type' do
          subject do
            described_class
              .new(three_months_from_now - 1.day)
              .data_from_employees_with_working_place_policy_with_previous_policy_of_different_type
          end

          xit { expect(subject.size).to eq 0 }
        end
      end
    end


    describe '#data_from_employees_with_employee_policy_with_previous_policy_of_different_type' do

      context 'when the policy is the current active for the given date one and the effective_at date match' do
        subject do
          described_class
            .new(three_months_from_now)
            .data_from_employees_with_employee_policy_with_previous_policy_of_different_type
        end
        it 'returns the data of for the employees that have a employee time off policy' do
          expected_result =
            {
              employee_id: employee.id,
              time_off_category_id: category.id,
              account_id: account.id
            }.with_indifferent_access
          expect(subject.first).to eq expected_result
          expect(subject.size).to eq 1
        end
      end

      context 'when the effective_at does not match the given date' do
        subject do
          described_class
            .new(three_months_from_now + 5.day)
            .data_from_employees_with_employee_policy_with_previous_policy_of_different_type
        end

        it { expect(subject.size).to eq 0 }
      end

      context 'when the effective_at matches but there are no employee with previous policy' do
        subject do
          described_class
            .new(Time.zone.today - 1.day)
            .data_from_employees_with_employee_policy_with_previous_policy_of_different_type
        end

        it { expect(subject.size).to eq 0 }

        context 'with different  type' do
          subject do
            described_class
              .new(three_months_from_now - 1.day)
              .data_from_employees_with_employee_policy_with_previous_policy_of_different_type
          end

          it { expect(subject.size).to eq 0 }
        end
      end
    end
  end
end
