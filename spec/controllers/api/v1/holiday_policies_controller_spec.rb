require 'rails_helper'

RSpec.describe API::V1::HolidayPoliciesController, type: :controller do
  include_context 'shared_context_headers'
  include_examples 'example_crud_resources',
    resource_name: 'holiday_policy'
  include_examples 'example_relationships_employees',
    resource_name: 'holiday_policy'
  include_examples 'example_relationships_working_places',
    resource_name: 'holiday_policy'

  describe 'POST #create' do
    context 'invalid data' do
      subject { post :create, params }

      context 'data does not pass validation' do
        let(:params) {{ name: 'test', region: 'ds' }}

        it 'should not create new holiday policy' do
          expect { subject }.to_not change { HolidayPolicy.count }
        end

        it 'should respond wth 422' do
          subject
          expect(response).to have_http_status(422)
          expect(response.body).to include "can't be blank"
        end
      end

      context 'not all required attributes send' do
        let(:holiday_policy) { create(:holiday_policy, account: account) }
        let(:params) {{ id: holiday_policy.id }}

        it 'should respond with 422' do
          subject
          expect(response).to have_http_status(422)
          expect(response.body).to include "missing"
        end
      end
    end
  end

  describe 'PUT #update' do
    subject { put :create, params }
    let(:holiday_policy) { create(:holiday_policy, account: account) }

    context 'invalid data' do
      context 'data does not pass validation' do
        let(:params) {{ name: 'test', region: 'ds', id: holiday_policy.id }}

        it 'should not change holiday_policy name' do
          expect { subject }.to_not change { holiday_policy.reload.name }
        end

        it 'should respond wth 422' do
          subject
          expect(response).to have_http_status(422)
          expect(response.body).to include "can't be blank"
        end
      end

      context 'not all required attributes send' do
        let(:params) {{ id: holiday_policy.id }}

        it 'should respond with 422' do
          subject
          expect(response).to have_http_status(422)
          expect(response.body).to include "missing"
        end
      end
    end
  end

  describe '/holiday-policies/:holiday_policy_id/relationships/holidays' do
    let(:holiday_policy) { create(:holiday_policy, account: account) }
    let(:second_holiday_policy) { create(:holiday_policy, account: account) }
    let(:holiday) { create(:holiday, holiday_policy: holiday_policy) }
    let(:first_holiday) { create(:holiday, holiday_policy: second_holiday_policy) }
    let(:second_holiday) { create(:holiday) }
    let(:params) {{ holiday_policy_id: holiday_policy.id, relationship: "holidays" }}

    context 'DELETE #destroy_relationship' do
      xit 'return 403 when holiday delete from holiday policy' do
        delete :destroy_relationship, params.merge(keys: holiday.id)

        expect(response).to have_http_status(403)
      end
    end

    context 'GET #show_relationship' do
      xit 'list all holiday policy holidays' do
        holiday_policy.holidays.push([first_holiday, second_holiday])
        holiday_policy.save

        get :show_relationship, params

        expect(response).to have_http_status(:success)
        expect(response.body).to include first_holiday.id
        expect(response.body).to include second_holiday.id
      end
    end

    context 'POST #create_relationship' do
      let(:first_holiday_json) do
        {
          "data": [
            { "type": "holidays",
              "id": first_holiday.id }
          ]
        }
      end

      let(:second_holiday_json) do
        {
          "data": [
            { "type": "holidays",
              "id": second_holiday.id }
          ]
        }
      end

      let(:invalid_holidays_json) do
        {
          "data": [
            { "type": "holidays",
              "id": '12345678-1234-1234-1234-123456789012' }
          ]
        }
      end

      xit 'assigns holiday to holiday_policy' do
        expect {
          post :create_relationship, params.merge(first_holiday_json)
        }.to change { holiday_policy.reload.holidays.size }.by(1)
      end

      xit 'changes holiday holiday_policy id' do
        expect {
          post :create_relationship, params.merge(first_holiday_json)
        }.to change { first_holiday.reload.holiday_policy_id }
      end

      xit 'returns status 400 if relation to holidays already exists' do
        holiday_policy.holidays.push(first_holiday)
        holiday_policy.save
        post :create_relationship, params.merge(first_holiday_json)

        expect(response).to have_http_status(400)
        expect(response.body).to include "Relation exists"
      end

      xit 'returns bad request when wrong holiday id given' do
        post :create_relationship, params.merge(invalid_holidays_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end

      xit 'returns bad request when user want to assign not his holiday' do
        post :create_relationship, params.merge(second_holiday_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end
    end
  end

  describe '/employee/:employee_id/holiday-policy' do
    let(:holiday_policy) { create(:holiday_policy) }
    let(:subject) do
      get :get_related_resource, employee_id: employee.id,
                                 relationship: "holiday_policy",
                                 source: "api/v1/employees"
    end

    context 'when employee has his holiday policy' do
      let(:employee) { create(:employee, holiday_policy: holiday_policy, account: account) }

      xit 'should return holiday policy' do
        subject

        expect(response.body).to include holiday_policy.id
      end
    end

    context 'when employee do not have holiday policy but his working place has' do
      let(:working_place) { create(:working_place, holiday_policy: holiday_policy) }
      let(:employee) { create(:employee, working_place: working_place, account: account) }

      xit 'should return holiday policy' do
        subject

        expect(employee.holiday_policy_id).to be nil
        expect(response.body).to include holiday_policy.id
      end
    end

    context 'when employee and his policy does not have holiday policy assigned' do
      let(:working_place) { create(:working_place) }
      let(:employee) { create(:employee, working_place: working_place, account: account) }

      xit 'should return holiday policy' do
        Account.current.holiday_policy_id = holiday_policy.id
        subject

        expect(employee.holiday_policy_id).to be nil
        expect(working_place.holiday_policy_id).to be nil
        expect(response.body).to include holiday_policy.id
      end
    end

    context 'when holiday policy not defined in employee, working place and account' do
      let(:working_place) { create(:working_place) }
      let(:employee) { create(:employee, working_place: working_place, account: account) }

      xit 'should return empty response' do
        subject

        expect(employee.holiday_policy_id).to be nil
        expect(working_place.holiday_policy_id).to be nil
        expect(account.holiday_policy_id).to be nil

        expect(response.body).to_not include holiday_policy.id
        expect(response).to have_http_status(200)
      end
    end
  end
end
