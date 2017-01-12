require 'rails_helper'

RSpec.describe CreateEvent do
  include_context 'shared_context_account_helper'

  before { Account.current = employee.account }

  let!(:definition) do
    create(:employee_attribute_definition,
      account: employee.account, name: attribute_name, multiple: true, validation: { presence: true })
  end
  let(:employee) { create(:employee) }
  let(:employee_id) { employee.id }
  let(:effective_at) { Date.today }
  let(:event_type) { 'job_details' }
  let(:value) { 'abc' }
  let(:attribute_name) { 'job_title' }
  let(:attribute_name_second) { 'job_title' }
  let(:params) do
    {
      effective_at: effective_at,
      event_type: event_type,
      comment: 'comment',
      employee: {
        id: employee_id,
        working_place_id: nil
      }
    }
  end
  let(:employee_attributes_params) do
    [
      {
        value: value,
        attribute_name: attribute_name,
        order: 1
      },
      {
        value: 'xyz',
        attribute_name: attribute_name_second,
        order: 2
      }
    ]
  end

  subject { described_class.new(params, employee_attributes_params).call }

  context 'with valid params' do
    context 'when employee_id is present' do
      it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }
      it { expect { subject }.to change { employee.events.count }.by(1) }

      it { expect(subject.effective_at).to eq effective_at }
      it { expect(subject.employee_attribute_versions.first.data.line).to eq value }

      context 'and nested attribute send' do
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

        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(3) }

        it 'has valid data' do
          subject

          expect(subject.employee_attribute_versions
            .where(attribute_definition: child_definition).first.data[:firstname]).to eq 'Arya'
        end
      end

      context 'and definition multiple is false' do
        before { definition.update(multiple: false) }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end

      context 'and definition has not validation' do
        before { definition.update(validation: nil) }

        let(:value ) { nil }

        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }
        it { expect { subject }.to_not raise_error }
      end
    end

    context 'when employee_id is not present' do
      let(:event_type) { 'hired'}
      let(:value) { 'Ned' }
      let(:attribute_name) { 'firstname' }
      let(:attribute_name_second) { 'nationality' }

      let!(:definition_second) do
        create(:employee_attribute_definition,
          account: employee.account, name: attribute_name_second, multiple: true, validation: nil)
      end

      let(:working_place) { create(:working_place, account: Account.current) }

      before do
        definition.update(name: attribute_name)
        params[:employee] = { working_place_id: working_place.id }
      end

      it { expect { subject }.to change { EmployeeWorkingPlace.count }.by(1) }
      it { expect { subject }.to change { Employee.count }.by(1) }
      it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }

      it { expect(subject.effective_at).to eq effective_at }
      it { expect(subject.employee_attribute_versions.first.data.line).to eq value }

      context 'and required attribute is nil or not send' do
        context 'and value is nil' do
          let(:value) { nil }

          it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
        end

        context 'and required attribute does not send' do
          before { employee_attributes_params.shift }

          it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
        end
      end

      context 'and definition does not have validation' do
        before { definition.update(validation: nil) }

        let(:value ) { nil }

        it { expect { subject }.to change { Employee::AttributeVersion.count }.by(2) }
        it { expect { subject }.to_not raise_error }
      end
    end
  end

  context 'with invalid params' do
    context 'and params are nil' do
      let(:params) { nil }

      it { expect { subject }.to raise_error(NoMethodError) }
    end

    context 'and definition is not multiple' do
      before { definition.update(multiple: false) }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context 'and employee attributes params are nil' do
      let(:employee_attributes_params) { nil }

      it { expect { subject }.to raise_error(NoMethodError) }
    end

    context 'and employee id is invalid' do
      let(:employee_id) { 'abc' }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'and employee id is nil' do
      let(:employee_id) { nil }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end
end
