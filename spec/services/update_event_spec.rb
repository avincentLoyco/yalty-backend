require 'rails_helper'

RSpec.describe do
  include_context 'shared_context_account_helper'

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
      before 'assign employee_working_place to employee' do
        create(:employee_working_place, employee: employee)
        employee.reload
      end

      context 'and this is event hired' do
        it { expect { subject }.to change { event.reload.effective_at } }
        it { expect { subject }
          .to change { employee.employee_working_places.first.reload.effective_at } }
      end

      context 'and this is not hired event' do
        let(:event_type) { 'change' }

        it { expect { subject }.to change { event.reload.effective_at } }
        it { expect { subject }
          .to_not change { employee.employee_working_places.first.reload.effective_at } }
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
    context 'when required param value set to null' do
      let(:effective_at) { nil }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context 'when required attribute does not send or value set to nil' do
      before do
        Employee::AttributeDefinition
          .where(name: 'firstname').first.update!(validation: { presence: true })
      end

      context 'when required attribute does not send' do
        before { employee_attributes_params.pop }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
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
