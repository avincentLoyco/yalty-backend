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
    subject { post :create, params }

    context 'valid data with empty arrays' do
      context 'empty array of holidays' do
        let(:params) {{ name: 'ab', holidays: [] }}

        it { expect { subject }.to change { HolidayPolicy.count }.by(1) }
        it { is_expected.to have_http_status(201) }
      end

      context 'empty array of working places' do
        let(:params) {{ name: 'ab', working_places: [] }}

        it { expect { subject }.to change { HolidayPolicy.count }.by(1) }
        it { is_expected.to have_http_status(201) }
      end

      context 'empty array of employees' do
        let(:params) {{ name: 'ab', employees: [] }}

        it { expect { subject }.to change { HolidayPolicy.count }.by(1) }
        it { is_expected.to have_http_status(201) }
      end
    end

    context 'invalid data' do
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
    subject { put :update, params }

    let!(:holiday_policy) { create(:holiday_policy, account: account) }
    let(:params) do
      {
        id: holiday_policy.id,
        name: 'test',
        employees: [],
        working_places: [],
        holidays: []
      }
    end

    context 'with empty array send' do
      context 'with empty array of employees' do
        let!(:employees) do
          create_list(:employee, 2, account: account, holiday_policy: holiday_policy)
        end

        it { expect { subject }.to change { holiday_policy.reload.employees.count }.from(2).to(0) }
        it { is_expected.to have_http_status 204 }
      end

      context 'with empty array of holidays' do
        let!(:holidays) { create_list(:holiday, 2, holiday_policy: holiday_policy ) }

        it { expect { subject }.to change { holiday_policy.reload.holidays.count }.from(2).to(0) }
        it { is_expected.to have_http_status 204 }
      end

      context 'with empty array of working_places' do
        let!(:working_places) do
          create_list(:working_place, 2, account: account, holiday_policy: holiday_policy)
        end

        it { expect { subject }.to change { holiday_policy.reload.working_places.count }
          .from(2).to(0) }
        it { is_expected.to have_http_status 204 }
      end
    end

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

  context 'holidays assign' do
    let(:holiday_policy) { create(:holiday_policy, account: account) }
    let(:second_holiday_policy) { create(:holiday_policy, account: account) }
    let(:holiday) { create(:holiday, holiday_policy: holiday_policy) }

    let(:first_holiday) { create(:holiday, holiday_policy: second_holiday_policy) }
    let(:second_holiday) { create(:holiday) }
    let(:third_holiday) { create(:holiday, holiday_policy: second_holiday_policy) }

    let(:first_holiday_json) do
      {
        holidays: [
          { "type": "holidays",
            "id": first_holiday.id }
        ]
      }
    end

    let(:second_holiday_json) do
      {
        holidays: [
          { "type": "holidays",
            "id": second_holiday.id }
        ]
      }
    end

    let(:both_holiday_json) do
      {
        holidays: [
          { "type": "holidays",
            "id": first_holiday.id },
          { "type": "holidays",
            "id": third_holiday.id }
        ]
      }
    end

    let(:invalid_holidays_json) do
      {
        holidays: [
          { "type": "holidays",
            "id": '12345678-1234-1234-1234-123456789012' }
        ]
      }
    end

    context 'PATCH #update' do
      let(:params) {{ id: holiday_policy.id }}

      it 'assigns holiday to holiday_policy' do
        expect {
          patch :update, params.merge(first_holiday_json)
        }.to change { holiday_policy.reload.custom_holidays.size }.by(1)
      end

      it 'allows for more than one holiday assign' do
        expect {
          patch :update, params.merge(both_holiday_json)
        }.to change { holiday_policy.reload.custom_holidays.size }.by(2)
      end

      it 'respond with success' do
        patch :update, params.merge(both_holiday_json)

        expect(response).to have_http_status(204)
      end

      it 'unnassign record which is not send' do
        holiday_policy.custom_holidays.push(first_holiday, third_holiday)
        expect(holiday_policy.custom_holidays.count).to eq(2)

        patch :update, params.merge(first_holiday_json)
        expect(holiday_policy.custom_holidays.count).to eq(1)
      end

      it 'delete record which is unnasigned' do
        holiday_policy.custom_holidays.push(first_holiday, third_holiday)
        expect(holiday_policy.custom_holidays.count).to eq(2)

        expect {
          patch :update, params.merge(first_holiday_json)
        }.to change { Holiday.count }.by(-1)
      end

      it 'returns bad request when wrong holiday id given' do
        patch :update, params.merge(invalid_holidays_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end

      it 'returns bad request when user want to assign not his holiday' do
        patch :update, params.merge(second_holiday_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end
    end

    context 'POST #create' do
      let(:params) { attributes_for(:holiday_policy) }

      it 'assigns holiday to holiday_policy' do
        expect {
          post :create, params.merge(first_holiday_json)
        }.to change { first_holiday.reload.holiday_policy_id }
      end

      it 'allows for more than one holiday assign' do
        expect {
          post :create, params.merge(both_holiday_json)
        }.to change { third_holiday.reload.holiday_policy_id }
      end

      it 'respond with success' do
        post :create, params.merge(both_holiday_json)

        expect(response).to have_http_status(201)
      end

      it 'returns bad request when wrong holiday id given' do
        post :create, params.merge(invalid_holidays_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end

      it 'returns bad request when user want to assign not his holiday' do
        post :create, params.merge(second_holiday_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end
    end
  end

  context 'multiple records assign' do
    let(:second_holiday_policy) { create(:holiday_policy, account: account) }

    let(:employees) { create_list(:employee, 2, account: account) }
    let(:working_places) { create_list(:working_place, 2, account: account) }
    let(:holidays) { create_list(:holiday, 2, holiday_policy: second_holiday_policy) }
    let(:holiday_policy_params) { attributes_for(:holiday_policy) }

    let(:valid_json) do
      {
        employees: [
          {
            id: employees.first.id,
            type: "employees"
          },
          {
            id: employees.last.id,
            type: "employees"
          }
        ],
        working_places: [
          {
            id: working_places.first.id,
            type: "working_places"
          },
          {
            id: working_places.last.id,
            type: "working_places"
          }
        ],
        holidays: [
          {
            id: holidays.first.id,
            type: "holidays"
          },
          {
            id: holidays.last.id,
            type: "holidays"
          }
        ]
      }
    end

    let(:invalid_json) do
      {
        working_places: [
          {
            id: working_places.first.id,
            type: "working_places"
          },
          {
            id: working_places.last.id,
            type: "working_places"
          }
        ],
        employees: [
          {
            id: '12345678-1234-1234-1234-123456789012',
            type: "employees"
          },
          {
            id: employees.last.id,
            type: "employees"
          }
        ],
        holidays: [
          {
            id: holidays.first.id,
            type: "holidays"
          },
          {
            id: '12345678-1234-1234-1234-123456789012',
            type: "holidays"
          }
        ]
      }
    end

    context 'POST #create' do
      context 'valid params' do
        subject { post :create, holiday_policy_params.merge(valid_json) }
        it 'should assign employees' do
          expect { subject }.to change { employees.first.reload.holiday_policy_id }
        end

        it 'should assign working places' do
          expect { subject }.to change { working_places.first.reload.holiday_policy_id }
        end

        it 'should assign holidays' do
          expect { subject }.to change { holidays.first.reload.holiday_policy_id }
        end

        it 'should respond with success' do
          subject

          expect(response).to have_http_status(201)
        end
      end
    end

    context 'PUTCH #update' do
      let(:holiday_policy) { create(:holiday_policy, account: account) }

      context 'valid params' do
        let(:params) {{ id: holiday_policy.id }}

         it 'should assign employees' do
          expect {
            patch :update, params.merge(valid_json)
          }.to change { holiday_policy.reload.employees.count }.by(2)
        end

        it 'should assign working places' do
          expect {
            patch :update, params.merge(valid_json)
          }.to change { holiday_policy.reload.working_places.count }.by(2)
        end

        it 'should assign holidays' do
          expect {
            patch :update, params.merge(valid_json)
          }.to change { holiday_policy.reload.holidays.count }.by(2)
        end

        it 'should respond with success' do
          patch :update, params.merge(valid_json)

          expect(response).to have_http_status(204)
        end
      end
      context 'invalid params' do
        let(:params) {{ id: holiday_policy.id }}

        it 'should assign employees' do
          expect {
            patch :update, params.merge(invalid_json)
          }.to_not change { holiday_policy.reload.employees.count }
        end

        it 'should assign working places' do
          expect {
            patch :update, params.merge(invalid_json)
          }.to_not change { holiday_policy.reload.working_places.count }
        end

        it 'should assign holidays' do
          expect {
            patch :update, params.merge(invalid_json)
          }.to_not change { holiday_policy.reload.holidays.count }
        end

        it 'should respond with success' do
          patch :update, params.merge(invalid_json)

          expect(response).to have_http_status(404)
        end
      end
    end
  end
end
