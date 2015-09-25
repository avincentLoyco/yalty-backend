require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do
  include_examples 'example_crud_resources',
    resource_name: 'working_place'

  let!(:working_place) { FactoryGirl.create(:working_place, account_id: account.id) }
  let(:working_place_json) do
    {
      "data": {
        "type": "working-places",
        "attributes": {
          "name": "Nice office"
        }
      }
    }
  end

  context 'POST /working_places' do
    it 'should create working_place for current account' do
      post :create, working_place_json

      expect(response).to have_http_status(:success)
      expect(account.working_places.size).to eq(2)
      expect(account.working_places.map(&:name)).to include working_place_json[:data][:attributes][:name]    end
  end

  describe '/working-places/:working_place_id/relationships/employees' do
    let!(:first_employee) { FactoryGirl.create(:employee, account_id: account.id) }
    let!(:second_employee) { FactoryGirl.create(:employee, account_id: account.id) }
    let(:params) {{ working_place_id: working_place.id, relationship: "employees" }}

    let(:first_employee_json) do
      {
        "data": [
          { "type": "employees",
            "id": first_employee.id }
        ]
      }
    end
    let(:second_employee_json) do
      {
        "data": [
          { "type": "employees",
            "id": second_employee.id }
        ]
      }
    end
    let(:both_employees_json) do
      {
        "data": [
          { "type": "employees",
            "id": first_employee.id },
          { "type": "employees",
            "id": second_employee.id }
        ]
      }
    end

    let(:invalid_employees_json) do
      {
        "data": [
          { "type": "employees",
            "id": '12345678-1234-1234-1234-123456789012' }
        ]
      }
    end

    context 'post #create_relationship' do
      it 'assigns employee to working place when new id given' do
        expect {
          post :create_relationship, params.merge(first_employee_json)
        }.to change { working_place.reload.employees.size }.from(0).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it 'adds employee to working place employees when new id given' do
        working_place.employees.push(first_employee)
        working_place.save
        expect {
          post :create_relationship, params.merge(second_employee_json)
        }.to change { working_place.reload.employees.size }.from(1).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it 'allows for adding few employees at time when new ids given' do
        expect {
          post :create_relationship, params.merge(both_employees_json)
        }.to change { working_place.reload.employees.size }.from(0).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns status 400 if employee already exists' do
        working_place.employees.push(first_employee)
        working_place.save

        post :create_relationship, params.merge(first_employee_json)

        expect(response).to have_http_status(400)
        expect(response.body).to include "Relation exists"
      end

      it 'returns bad request when wrong working place id given' do
        params = { working_place_id: '12345678-1234-1234-1234-123456789012',
                   relationship: "employees" }
        post :create_relationship, params.merge(first_employee_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end

      it 'returns bad request when wrong employee id given' do
        post :create_relationship, params.merge(invalid_employees_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end

      it 'returns 400 when parameters not given' do
        post :create_relationship, params

        expect(response).to have_http_status(400)
        expect(response.body).to include "Missing Parameter"
      end
    end

    context 'delete #destroy_relationship' do
      it 'delete employee from relationship if exist' do
        working_place.employees.push(first_employee)
        working_place.save
        expect {
          delete :destroy_relationship, params.merge(keys: first_employee.id)
        }.to change { working_place.reload.employees.size }.from(1).to(0)

        expect(response).to have_http_status(:no_content)
      end

      it 'return 404 when wrong employee id given' do
        post :destroy_relationship, params.merge(
          keys: '12345678-1234-1234-1234-123456789012'
        )

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end
    end

    context 'get #show_relationship' do
      it 'list all working place employees' do
        working_place.employees.push([first_employee, second_employee])
        working_place.save

        get :show_relationship, params

        expect(response).to have_http_status(:success)
        expect(response.body).to include first_employee.id
        expect(response.body).to include second_employee.id
      end
    end
  end
end
