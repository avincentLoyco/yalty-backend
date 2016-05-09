require 'rails_helper'

RSpec.describe ValidateDeletabilityOfTimeOffPolicyJoinTable, type: :service do

  describe '#call' do
    include_context 'shared_context_timecop_helper'
    let(:account) { create(:account) }
    let(:employee) { create(:employee, account: account) }
    let(:working_place) { employee.employee_working_places.last.working_place }
    let(:category_A) { create(:time_off_category, account: account) }
    let(:category_B) { create(:time_off_category, account: account) }
    let(:time_off_policy_A) { create(:time_off_policy, time_off_category: category_A) }
    let(:time_off_policy_B) { create(:time_off_policy, time_off_category: category_A) }
    let!(:employee_time_off_policy_1_1_2016) do
      create(
        :employee_time_off_policy,
        :with_employee_balance,
        employee: employee,
        effective_at: Time.zone.now,
        time_off_policy: time_off_policy_A
      )
    end
    let!(:employee_time_off_policy_8_1_2016) do
      create(
        :employee_time_off_policy,
        employee: employee,
        effective_at: Time.zone.now + 7.days,
        time_off_policy: time_off_policy_B
      )
    end
    let(:balance) { Employee::Balance.last }
    context 'when the resource is a EmployeeTimeOffPolicy' do
      context "and there is an associated balance to the employee" do
        context "in a period while the resource was active" do
          let(:error_message) do
            "Can't remove EmployeeTimeOffPolicy it has a related balance"
          end
          it '' do
            expect{
              described_class.new(employee_time_off_policy_1_1_2016).call
            }.to raise_error(CanCan::AccessDenied, error_message)
          end
        end
        context "in a period while the resource was inactive" do
          it '' do
            balance.update_attribute(:effective_at, Time.zone.today + 9.days - 1.hour)
            expect(
              described_class.new(employee_time_off_policy_1_1_2016).call
            ).to be true
          end
        end
      end
      context "when there are no associated balances in the category" do
        it '' do
          balance.update_attribute(:time_off_category, category_B)
          expect(
            described_class.new(employee_time_off_policy_1_1_2016).call
          ).to be true
        end
      end
    end

    context 'when the resource is a WorkingPlaceTimeOffPolicy' do
      let!(:working_place_time_off_policy_25_12_2015) do
        create(
          :working_place_time_off_policy,
          working_place: working_place,
          effective_at: Time.zone.now - 7.days,
          time_off_policy: time_off_policy_A
        )
      end
      let!(:working_place_time_off_policy_28_12_2015) do
        create(
          :working_place_time_off_policy,
          working_place: working_place,
          effective_at: Time.zone.now - 4.days,
          time_off_policy: time_off_policy_B
        )
      end
      context "and there is an associated balance to the employee" do
        context "in a period while the resource was active" do
          let(:error_message) do
            "Can't remove WorkingPlaceTimeOffPolicy it has a related balance"
          end
          it '' do
            balance.update_attribute(:effective_at, Time.zone.today - 5.days)
            expect{
              described_class.new(working_place_time_off_policy_25_12_2015).call
            }.to raise_error(CanCan::AccessDenied, error_message)
          end
        end
        context "in a period while the resource was inactive" do
          it '' do
            balance.update_attribute(:effective_at, Time.zone.today - 3.days)
            expect(
              described_class.new(working_place_time_off_policy_25_12_2015).call
            ).to be true
          end
          it '' do
            expect(
              described_class.new(working_place_time_off_policy_25_12_2015).call
            ).to be true
          end
        end
      end
      context "when there are no associated balances in the category" do
        it '' do
          balance.update_attribute(:time_off_category, category_B)
          expect(
            described_class.new(working_place_time_off_policy_25_12_2015).call
          ).to be true
        end
      end
    end
  end
end
