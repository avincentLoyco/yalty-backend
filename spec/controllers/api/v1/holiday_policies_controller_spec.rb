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
end
