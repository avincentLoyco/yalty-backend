require 'rails_helper'

RSpec.describe API::V1::HolidayPoliciesController, type: :controller do
  include_examples 'example_crud_resources',
    resource_name: 'holiday_policy'
  include_examples 'example_relationships_employees',
    resource_name: 'holiday_policy'
  include_examples 'example_relationships_working_places',
    resource_name: 'holiday_policy'
  include_examples 'example_relationships_holidays',
    resource_name: 'holiday_policy'

  describe '/#{settings[:resource_name]}/:resource_id/relationships/holidays' do
    let!(:holiday_policy) { create(:holiday_policy, account: account) }
    let!(:holiday) { create(:holiday, holiday_policy: holiday_policy) }
    let(:params) {{ holiday_policy_id: holiday_policy.id, relationship: "holidays" }}

    context 'DELETE #destroy_relationship' do
      it 'return 403 when holiday delete from holiday policy' do
        delete :destroy_relationship, params.merge(keys: holiday.id)

        expect(response.status).to eq 403
      end
    end
  end

  describe '/employee/:employee_id/holiday-policy' do
    let(:holiday_policy) { create(:holiday_policy) }

    context 'when employee has his holiday policy' do
      let(:employee) { create(:employee, holiday_policy: holiday_policy, account: account) }

      it 'should return holiday policy' do
        get :get_related_resource, employee_id: employee.id, relationship: "holiday_policy", source: "api/v1/employees"

        expect(response.body).to include holiday_policy.id
      end
    end

    context 'when employee do not have holiday policy but his working place has' do
      let(:working_place) { create(:working_place, holiday_policy: holiday_policy) }
      let(:employee) { create(:employee, working_place: working_place, account: account) }

      it 'should return holiday policy' do
        get :get_related_resource, employee_id: employee.id, relationship: "holiday_policy", source: "api/v1/employees"

        expect(employee.holiday_policy_id).to be nil
        expect(response.body).to include holiday_policy.id
      end
    end

    context 'when employee and his policy does not have holiday policy assigned' do
      let(:working_place) { create(:working_place) }
      let(:employee) { create(:employee, working_place: working_place, account: account) }

      it 'should return holiday policy' do
        Account.current.holiday_policy_id = holiday_policy.id
        get :get_related_resource, employee_id: employee.id, relationship: "holiday_policy", source: "api/v1/employees"

        expect(employee.holiday_policy_id).to be nil
        expect(working_place.holiday_policy_id).to be nil
        expect(response.body).to include holiday_policy.id
      end
    end
  end
end
