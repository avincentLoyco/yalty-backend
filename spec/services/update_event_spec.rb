require 'rails_helper'

RSpec.describe do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  before do
    Account.current = employee.account
    Account::User.current = create(:account_user, account: employee.account)
  end
  subject { UpdateEvent.new(params, employee_attributes_params).call }
  let!(:definition) do
    create(:employee_attribute_definition,
      account: employee.account, name: 'firstname', multiple: true, validation: { presence: true })
  end
  let(:first_name_order) { 1 }
  let(:employee) { create(:employee, :with_attributes) }
  let(:event) { employee.events.first }
  let(:event_id) { event.id }
  let(:first_attribute) { event.employee_attribute_versions.first }
  let(:second_attribute) { event.employee_attribute_versions.last }
  let(:effective_at) { Time.now - 2.years }
  let(:first_name_value) { 'John' }
  let(:event_type) { 'hired' }
  let(:employee_id) { employee.id }
  let(:params) do
    {
      id: event_id,
      effective_at: effective_at,
      event_type: event_type,
      comment: 'comment',
      employee: {
        id: employee_id
      }
    }
  end
  let(:employee_attributes_params) do
    [
      {
        value: 'Snow',
        id: first_attribute.id,
        attribute_name: first_attribute.attribute_definition.name
      },
      {
        value: 'Stark',
        id: second_attribute.id,
        attribute_name: second_attribute.attribute_definition.name
      },
      {
        value: first_name_value,
        attribute_name: 'firstname',
        order: first_name_order
      }
    ]
  end

  context 'with valid params' do
    context 'when attributes id send' do
      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(1) }
      it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
      it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
    end

    context 'when not all event attributes send' do
      before { employee_attributes_params.shift(2) }

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(-1) }
    end

    context 'forbbiden attributes' do
      before do
        employee_attributes_params.pop
        event.reload.employee_attribute_versions
        definition.update!(validation: nil)
      end
      let!(:salary_attribute) do
        create(:employee_attribute_version,
          employee: employee, attribute_definition: salary_definition, data: { line: '2000' },
          event: event)
      end
      let!(:salary_definition) do
        create(:employee_attribute_definition,
          account: employee.account, name: 'annual_salary', validation: { presence: true })
      end

      context 'when account manager updates event' do
        before { Account::User.current.update!(account_manager: true) }

        context 'and forbiden attribute is send' do
          before do
            employee_attributes_params.push(
              { value: 3000, attribute_name: 'annual_salary', id: salary_attribute.id }
            )
          end

          it { expect { subject }.to_not change { event.employee_attribute_versions.count } }
          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it { expect { subject }.to change { salary_attribute.reload.data.value }.to eq '3000' }
        end

        context 'and forbiden attribute is not send' do
          it { expect { subject }.to change { event.employee_attribute_versions.count }.by(-1) }
          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it 'should destroy salary attribute' do
            expect { subject }.to change {
              Employee::AttributeVersion.exists?(salary_attribute.id)
            }.to false
          end
        end
      end

      context 'when employee who is not an account manager updates event' do
        context 'and he only does not send forbiddean version' do
          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it { expect { subject }.to_not change { event.employee_attribute_versions.count } }
          it 'should not destroy salary attribute' do
            expect { subject }.to_not change {
              Employee::AttributeVersion.exists?(salary_attribute.id)
            }
          end
        end

        context 'and he does not send a few params including forbiddean version' do
          let!(:firstname_attribute) do
            create(:employee_attribute_version,
              employee: employee, attribute_definition: definition, data: { string: 'test' },
              event: event, order: 1
            )
          end

          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it { expect { subject }.to change { event.employee_attribute_versions.count }.by(-1) }
          it 'should destroy firstname attribute' do
            expect { subject }.to change {
              Employee::AttributeVersion.exists?(firstname_attribute.id)
            }.to false
          end
          it 'should not destroy salary attribute' do
            expect { subject }.to_not change {
              Employee::AttributeVersion.exists?(salary_attribute.id)
            }
          end
        end
      end
    end

    context 'when effective at changes' do
      before do
        versions = employee.reload.employee_attribute_versions
        versions.first.update!(attribute_definition: definition, data: { string: 'a' })
        employee.events.first.update!(effective_at: 2.years.ago + 1.day)
        employee_attributes_params.shift
        [[20, etops.first], [30, etops.last], [40, new_etop]].map do |manual_amount, etop|
          etop.policy_assignation_balance.update!(
            manual_amount: manual_amount, policy_credit_addition: false
          )
        end
      end

      let(:first_category) { create(:time_off_category, account: employee.account) }
      let(:second_category) { create(:time_off_category, account: employee.account) }
      let!(:ewp) do
        create(:employee_working_place, employee: employee, effective_at: 2.years.ago + 1.day)
      end
      let!(:etops) do
        [first_category, second_category].map do |category|
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, effective_at: 2.years.ago + 1.day,
            time_off_policy:
              create(:time_off_policy, :with_end_date, time_off_category: category)
          )
        end
      end
      let!(:new_etop) do
        create(:employee_time_off_policy, :with_employee_balance,
          employee: employee, effective_at: 2.years.ago + 5.days,
          time_off_policy:
            create(:time_off_policy, :with_end_date,time_off_category: first_category)
        )
      end
      let!(:epp) do
        create(:employee_presence_policy, employee: employee, effective_at: 2.years.since)
      end
      let!(:first_balance) { etops.first.policy_assignation_balance }
      let!(:second_balance) { etops.last.policy_assignation_balance }
      let!(:newest_balance) { new_etop.policy_assignation_balance }
      let(:effective_at) { 1.year.since }

      context 'and this is event hired' do
        context 'and date move to the future' do
          it { expect { subject }.to change { event.reload.effective_at } }
          it { expect { subject }.to change { ewp.reload.effective_at } }
          it { expect { subject }.to change { etops.last.reload.effective_at } }
          it { expect { subject }.to change { new_etop.reload.effective_at } }
          it { expect { subject }.to change { newest_balance.reload.effective_at } }
          it { expect { subject }.to change { second_balance.reload.effective_at } }
          it do
            expect { subject }.to change { newest_balance.reload.policy_credit_addition }.to true
          end

          it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }
          it { expect { subject }.to change { Employee::Balance.exists?(first_balance.id) } }
          it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

          it { expect { subject }.to_not change { second_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { newest_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { epp.reload.effective_at } }

          context 'it does not change policy credit addition to true while not policy start date' do
            let(:effective_at) { 1.year.since + 1.day }

            it { expect { subject }.to_not change { newest_balance.reload.policy_credit_addition } }
          end
        end

        context 'and date move to the past' do
          before do
            EmployeeTimeOffPolicy.all.map do |etop|
              ManageEmployeeBalanceAdditions.new(etop).call
            end
            params[:effective_at] = 3.years.ago
          end

          it { expect { subject }.to change { event.reload.effective_at } }
          it { expect { subject }.to change { ewp.reload.effective_at } }
          it { expect { subject }.to change { etops.last.reload.effective_at } }
          it { expect { subject }.to change { etops.first.reload.effective_at } }
          it { expect { subject }.to change { first_balance.reload.effective_at } }
          it { expect { subject }.to change { second_balance.reload.effective_at } }
          it { expect { subject }.to change { Employee::Balance.additions.count }.by(4) }
          it { expect { subject }.to change { Employee::Balance.removals.count }.by(2) }
          it { expect { subject }.to change { Employee::Balance.count}.by(6) }

          it { expect { subject }.to_not change { first_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { second_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { newest_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { new_etop.reload.effective_at } }
          it { expect { subject }.to_not change { newest_balance.reload.effective_at } }
          it { expect { subject }.to_not change { epp.reload.effective_at } }

          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }

          context 'it does not change policy credit addition to true while not policy start date' do
            let(:effective_at) { 3.years.ago + 1.day }

            it { expect { subject }.to_not change { newest_balance.reload.policy_credit_addition } }
          end
        end
      end

      context 'and this is not hired event' do
        let(:event_type) { 'change' }

        it { expect { subject }.to change { event.reload.effective_at } }
        it { expect { subject }.to_not change { ewp.reload.effective_at } }
        it { expect { subject }.to_not change { etops.last.reload.effective_at } }
        it { expect { subject }.to_not change { new_etop.reload.effective_at } }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }

        it { expect { subject }.to_not change { epp.reload.effective_at } }
      end

      context 'when there are employee balances between previous hired date and new hired date' do
        before do
          create(:time_off,
            start_time: employee.hired_date + 1.month,
            end_time: employee.hired_date + 2.months, employee: employee)
        end

        it { expect { subject }.to raise_error(ActiveRecord::RecordInvalid) }
      end
    end

    context 'when multiple attributes send' do
      before do
        employee_attributes_params.unshift(
          {
            value: 'ned',
            attribute_name: 'firstname',
            order: 2
          }
        )
      end

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(2) }
    end

    context 'when nested attribute send' do
      let!(:child_definition) do
        create(:employee_attribute_definition,
          account: employee.account, name: 'child', attribute_type: 'Child')
      end

      before do
        employee_attributes_params.unshift(
          {
            attribute_name: 'child',
            order: 2,
            value: {
              lastname: 'Stark',
              firstname: 'Arya'
            }
          }
        )
      end

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(2) }
      it 'has valid data' do
        subject
        expect(event.employee_attribute_versions.where(attribute_definition: child_definition)
          .first.data.value[:firstname]).to eq('Arya')
      end
    end
  end

  context 'with invalid params' do
    context 'when required attribute does not send or value set to nil' do
      before do
        Employee::AttributeDefinition
          .where(name: 'firstname').first.update!(validation: { presence: true })
      end

      context 'when required attribute does not send' do
        before { employee_attributes_params.pop }

        it { expect { subject }.to raise_error(ActiveRecord::RecordInvalid) }
      end

      context 'when required attribute value set to nil' do
        let(:first_name_value) { nil }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end

    context 'when order does not send for multiple attribute' do
      let(:first_name_order) { nil }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context 'with invalid employee id' do
      let(:employee_id) { 'ab' }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'with invalid event id' do
      let(:event_id) { 'ab' }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end
end
