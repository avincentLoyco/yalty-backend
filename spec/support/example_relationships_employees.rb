RSpec.shared_examples 'example_relationships_employees' do |settings|
  include_context 'shared_context_headers'
  let(:resource_name) { settings[:resource_name] }
  let(:resource_id) { "#{settings[:resource_name]}_id" }

  describe "/#{settings[:resource_name]}/:resource_id" do
    let!(:first_employee) { create(:employee, account: account) }
    let!(:second_employee) { create(:employee, account: account) }
    let(:resource) { create(resource_name, account: account) }
    let(:params) {{ id: resource.id }}

    let(:first_employee_json) do
      {
        employees: [
          {
            "type": "employees",
            "id": first_employee.id
          }
        ]
      }
    end
    let(:second_employee_json) do
      {
        employees: [
          {
            "type": "employees",
            "id": second_employee.id
          }
        ]
      }
    end
    let(:both_employees_json) do
      {
        employees: [
          {
            "type": "employees",
            "id": first_employee.id
          },
          {
            "type": "employees",
            "id": second_employee.id
          }
        ]
      }
    end

    let(:invalid_employees_json) do
      {
        employees: [
          {
            "type": "employees",
            "id": '12345678-1234-1234-1234-123456789012'
          }
        ]
      }
    end

    context 'post #create_relationship' do
      it 'assigns employee to working place when new id given' do
        expect {
          patch :update, params.merge(first_employee_json)
        }.to change { resource.reload.employees.size }.from(0).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it 'adds employee to working place employees when new id given' do
        resource.employees.push(first_employee)
        resource.save
        expect {
          patch :update, params.merge(second_employee_json)
        }.to change { resource.reload.employees.size }.from(1).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it 'allows for adding few employees at time when new ids given' do
        expect {
          patch :update, params.merge(both_employees_json)
        }.to change { resource.reload.employees.size }.from(0).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns status 204 if employee already exists' do
        resource.employees.push(first_employee)
        resource.save

        expect(resource.employees.count).to eq(1)
        patch :update, params.merge(first_employee_json)

        expect(response).to have_http_status(204)
        expect(resource.employees.count).to eq(1)
      end

      it 'returns bad request when wrong working place id given' do
        params = { id: '12345678-1234-1234-1234-123456789012' }
        patch :update, params.merge(first_employee_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end

      it 'returns bad request when wrong employee id given' do
        patch :update, params.merge(invalid_employees_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end

      xit 'returns 400 when parameters not given' do
        patch :update, params

        expect(response).to have_http_status(400)
        expect(response.body).to include "Missing Parameter"
      end
    end

    context 'delete #destroy_relationship' do
      xit 'delete employee from relationship if exist' do
        resource.employees.push(first_employee)
        resource.save
        expect {
          delete :destroy_relationship, params.merge(keys: first_employee.id)
        }.to change { resource.reload.employees.size }.from(1).to(0)

        expect(response).to have_http_status(:no_content)
      end

      xit 'return 404 when wrong employee id given' do
        post :destroy_relationship, params.merge(
          keys: '12345678-1234-1234-1234-123456789012'
        )

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end
    end

    context 'get #show_relationship' do
      xit 'list all working place employees' do
        resource.employees.push([first_employee, second_employee])
        resource.save

        get :show_relationship, params

        expect(response).to have_http_status(:success)
        expect(response.body).to include first_employee.id
        expect(response.body).to include second_employee.id
      end
    end
  end
end
