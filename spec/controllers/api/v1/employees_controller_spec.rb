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
    let(:employee) { create(:employee, :with_attributes, account: account) }
    let(:employee_working_place) { employee.first_employee_working_place }
    let(:first_working_place) { employee_working_place.working_place }
    let(:future_working_place) { future_employee_working_place.working_place }
    let!(:future_employee_working_place) do
      create(:employee_working_place, employee: employee, effective_at: Time.now + 1.month)
    end

    subject { get :show, id: employee.id }

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
        let!(:definition) { create(:employee_attribute_definition, multiple: true) }
        let!(:new_employee) { build(:employee, account: account, events: [employee_event]) }
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
            it { expect_json('employee_attributes.0', type: 'employee_attribute') }
          end
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
    let!(:employees) { create_list(:employee, 3, :with_attributes, account: account) }
    subject { get :index }

    it { is_expected.to have_http_status(200) }

    context 'response' do
      before { subject }

      it { expect_json_sizes(3) }
      it { expect_json_types(
        '*', id: :string, type: :string, employee_attributes: :array)
      }
    end

    context 'effective at date' do
      let!(:future_employee) { create(:employee, account: account, events: [event]) }
      let!(:attribute) { create(:employee_attribute, event: event, employee: future_employee) }
      let!(:event) { create(:employee_event, effective_at: date, event_type: 'hired') }
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
              'type' => 'employee_attribute',
              'order' => attribute.order
            )
          }
          it { expect(employee_body['id']).to eql(future_employee.id) }
          it { expect(employee_body['already_hired']).to eql true }
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
          it { expect(employee_body['already_hired']).to eql false }
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

        it { expect_json_sizes(0) }
      end
    end
  end
end
