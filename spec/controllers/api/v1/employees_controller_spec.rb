require 'rails_helper'

RSpec.describe API::V1::EmployeesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'employee', create: false , update: false, delete: false
  include_context 'shared_context_headers'

  let(:attribute_definition) {
    create(
      :employee_attribute_definition,
      attribute_type: 'String',
      account: account
    )
  }

  context 'GET #show' do
    let!(:employee) { create(:employee_with_working_place, :with_attributes, account: account) }
    let!(:employee_working_place) { employee.first_employee_working_place }
    let!(:first_working_place) { employee_working_place.working_place }
    let!(:future_working_place) { future_employee_working_place.working_place }
    let!(:future_employee_working_place) do
      create(:employee_working_place, employee: employee, effective_at: Time.now + 1.month)
    end

    subject { get :show, id: employee.id }

    context 'when employee does not have working place' do
      before { EmployeeWorkingPlace.destroy_all }

      it { is_expected.to have_http_status(200) }
    end

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'when the first policy is active one' do
        before { subject }

        it 'have active policy in json' do
          expect_json('working_place',
            id: first_working_place.id,
            type: 'working_place',
            assignation_id: employee_working_place.id
          )
        end

        it 'has civil status date, civil status and hired date in json' do
          expect_json(
            civil_status: 'single',
            civil_status_date: nil,
            hired_date: employee.hired_date.to_s,
            contract_end_date: nil
          )
        end
      end

      context 'when employee is hired in future with previous event' do
        let!(:employee) { create(:employee_with_working_place, :with_attributes, account: account, hired_at: 1.month.from_now) }

        before do
          event = create(:employee_event, employee: employee)
          create(:employee_attribute, employee: employee, event: event)
        end

        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }

          it { expect_json_sizes(employee_attributes: 3) }
          it { expect_json('employee_attributes.0', type: 'employee_attribute_version') }
        end
      end

      context 'when employee has contract end' do
        before do
          create(:employee_event,
            event_type: 'contract_end', employee: employee, effective_at: contract_end_date
          )
          subject
        end

        context 'when contract end in the future' do
          let(:contract_end_date) { 1.months.since }

          it do
            expect_json('working_place',
              id: first_working_place.id,
              type: 'working_place',
              effective_till: (contract_end_date - 1.day).to_date.to_s,
              assignation_id: employee_working_place.id
            )
          end
        end

        context 'when contract end today' do
          let(:contract_end_date) { Time.zone.today - 1.day }

          it { expect_json('working_place', {}) }
        end
      end

      context 'when future policy is now active one' do
        before do
          Timecop.freeze(Time.now + 1.month)
          employee.reload.employee_working_places
          subject
        end

        after do
          Timecop.return
        end

        it 'have future policy in json' do
          expect_json('working_place',
            id: future_working_place.id,
            type: 'working_place',
            assignation_id: future_employee_working_place.id
          )
        end
      end

      context 'response' do
        before { subject }

        it { expect_json_keys('employee_attributes.*',
          [:id, :type, :value, :attribute_name, :order]) }
        it { expect_json_types(id: :string, type: :string, employee_attributes: :array) }
      end

      context 'when employee has multiple attributes' do
        let!(:definition) { create(:employee_attribute_definition, multiple: true, account: account) }
        let!(:new_employee) do
          build(:employee_with_working_place, account: account, events: [employee_event])
        end
        let!(:employee_attribute_versions) do
          create_list(:employee_attribute, 2,
            employee: new_employee,
            employee_event_id: employee_event.id,
            attribute_definition_id: definition.id,
            multiple: true
          )
        end

        subject { get :show, id: new_employee.id }

        context 'when employee is not effective at' do
          let!(:employee_event) do
            create(:employee_event,
              effective_at: Time.now + 1.week,
              event_type: 'hired'
            )
          end

          it { expect(new_employee.employee_attribute_versions.count).to eq (2) }
          it { expect(new_employee.employee_attributes.count).to eq(0) }
          it { expect(new_employee.events.count).to eql(1) }
          it { expect(new_employee.events.first.effective_at).to be >= Time.now }

          it { is_expected.to have_http_status(200) }

          context 'response body' do
            before { subject }

            it { expect_json_sizes(employee_attributes: 2) }
            it { expect_json('employee_attributes.0', type: 'employee_attribute_version') }
          end
        end

        context 'when employee event is effective at' do
          let!(:employee_event) do
            create(:employee_event,
              effective_at: Time.now - 1.week,
              event_type: 'hired'
            )
          end

          it { expect(new_employee.employee_attribute_versions.count).to eq (2) }
          it { expect(new_employee.employee_attributes.count).to eq(2) }
          it { expect(new_employee.events.count).to eql(1) }

          it { is_expected.to have_http_status(200) }

          context 'response body' do
            before { subject }

            it { expect_json_sizes(employee_attributes: 2) }
            it { expect_json('employee_attributes.0', type: 'employee_attribute_version') }
          end
        end
      end

      context 'active_presence_policy' do
        let!(:epp) { create(:employee_presence_policy, employee: employee, effective_at: 1.day.ago)}

        before { subject }

        it 'returns proper policy data' do
          expect_json_keys('active_presence_policy', [:id, :type, :standard_day_duration])
        end
      end
    end

    context 'with invalid data' do
      context 'with invalid employee id' do
        subject { get :show, id: '1' }

        it { is_expected.to have_http_status(404) }
      end

      context 'with not account employee' do
        before(:each) do
          user = create(:account_user)
          Account.current = user.account
        end

        it { is_expected.to have_http_status(404) }
      end
    end
  end

  context 'GET #index' do
    let!(:employees) do
      create_list(:employee_with_working_place, 3, :with_attributes, account: account) << user.employee
    end
    subject { get :index }

    it { is_expected.to have_http_status(200) }

    context 'response' do
      before { subject }

      it { expect_json_sizes(4) }
      it { expect_json_types(
        '*', id: :string, type: :string, employee_attributes: :array)
      }
    end

    context 'status parameter' do
      context 'when status not sent' do
        it 'get all employees' do
          expect(Account.current).to receive_message_chain(:employees, :all)
          subject
        end
      end

      context 'when status sent' do
        subject(:index_with_status) { get :index, status }

        context 'status active' do
          let(:status) {{ status: 'active' }}

          it 'get active employees' do
            expect(Account.current).to receive_message_chain(:employees, :active_at_date)
            index_with_status
          end
        end

        context 'status inactive' do
          let(:status) {{ status: 'inactive' }}

          it 'get active employees' do
            expect(Account.current).to receive_message_chain(:employees, :inactive_at_date)
            index_with_status
          end
        end
      end
    end

    context 'attributes' do
      let!(:public_definition) do
        create(:employee_attribute_definition, name: 'firstname',
          attribute_type: Attribute::String.attribute_type, account: account)
      end
      let!(:user) { create(:account_user, account: account, employee: employee, role: 'user') }
      let(:employee) { create(:employee_with_working_place, :with_attributes, account: account) }
      let(:employee_with_public_attribute) { employees.find { |e| e.id != user.employee.id } }

      before do
        employee_with_public_attribute.events.last.employee_attribute_versions << build(
          :employee_attribute_version, attribute_definition: public_definition,
          attribute_name: 'firstname', value: 'Mirek', employee: employee_with_public_attribute,
          event: employee_with_public_attribute.events.last)

        subject
      end

      context 'advanced when employee belongs to current user' do
        it do
          result = JSON.parse(response.body).find { |e| e["id"] == user.employee.id }
          expect(result['employee_attributes'].size).to eq(2)
        end
      end

      context 'simple for other employees' do
        it do
          result = JSON.parse(response.body).find { |e| e["id"] == employee_with_public_attribute.id }
          expect(result['employee_attributes'].size).to eq(1)
        end
      end
    end

    context 'effective at date' do
      let!(:future_employee) do
        create(:employee_with_working_place, account: account, events: [event])
      end
      let!(:attribute) { create(:employee_attribute, event: event, employee: future_employee) }
      let(:event) { create(:employee_event, effective_at: date, event_type: 'hired') }
      let(:employee_body) do
        JSON.parse(response.body).select { |record| record['id'] == future_employee.id }.first
      end

      context 'employee with past effective_at date' do
        let(:date) { Time.zone.now - 1.month }

        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }

          it { expect(employee_body['employee_attributes'].first).to eql(
              'attribute_name' => attribute.attribute_definition.name,
              'value' => attribute.data.value,
              'id' => attribute.id,
              'type' => 'employee_attribute_version',
              'order' => attribute.order
            )
          }
          it { expect(employee_body['id']).to eql(future_employee.id) }
          it { expect(employee_body['hiring_status']).to eql false }
        end
      end

      context 'employee with future effective at date' do
        let(:date) { Time.zone.now + 1.month }

        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }

          it { expect(employee_body['employee_attributes'].first).to eql(
              'attribute_name' => attribute.attribute_definition.name,
              'value' => attribute.data.value,
              'id' => attribute.id,
              'type' => 'employee_attribute_version',
              'order' => attribute.order
            )
          }
          it { expect(employee_body['id']).to eql(future_employee.id) }
          it { expect(employee_body['hiring_status']).to eql false }
        end
      end
    end

    context 'should not be visible in context of other account' do
      before(:each) do
        user = create(:account_user)
        Account.current = user.account
      end

      it { is_expected.to have_http_status(200) }

      context 'response' do
        before { subject }

        it { expect_json_sizes(1) }
      end
    end
  end
end
