RSpec.shared_examples 'example_relationships_employees' do |settings|
  include_context 'shared_context_headers'
  let(:resource_name) { settings[:resource_name] }
  let(:resource_id) { "#{settings[:resource_name]}_id" }

  describe "/#{settings[:resource_name]}/:resource_id" do
    let!(:first_employee) { create(:employee, account: account) }
    let!(:second_employee) { create(:employee, account: account) }
    let(:resource) { create(resource_name, account: account) }
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

    let(:empty_employee_array_json) do
      {
        employees: []
      }
    end

    let(:resource_params) { attributes_for(settings[:resource_name]) }
    let(:params) { resource_params.merge({ id: resource.id }) }
    let(:resource_param) { attributes_for(settings[:resource_name]).keys.first }
    let(:empty_employee_json) do
      {
        resource_param => 'test'
      }
    end

    context 'post #create_relationship' do
      it 'assigns employee to working place when new id given' do
        expect {
          patch :update, params.merge(first_employee_json)
        }.to change { resource.reload.employees.size }.from(0).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it 'overwrites employees set when new id given' do
        resource.employees.push(first_employee, second_employee)
        resource.save

        expect(resource.employees.count).to eq(2)
        expect {
          patch :update, params.merge(second_employee_json)
        }.to change { resource.employees.count }.from(2).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it 'overwrties all employees from resource when empty array send' do
        resource.employees.push(first_employee, second_employee)
        resource.save

        expect(resource.employees.count).to eq(2)
        expect {
          patch :update, params.merge(empty_employee_array_json)
        }.to change { resource.reload.employees.size }.from(2).to(0)

        expect(response).to have_http_status(:no_content)
      end

      it 'does not overwrite employees when params without employees send' do
        resource.employees.push(first_employee, second_employee)
        resource.save

        expect(resource.employees.count).to eq(2)
        patch :update, params.merge(empty_employee_json)

        expect(resource.reload[resource_param]).to eq('test')
        expect(resource.reload.employees.count).to eq (2)

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
        params = resource_params.merge({ id: '12345678-1234-1234-1234-123456789012' })
        patch :update, params.merge(first_employee_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end

      it 'returns bad request when wrong employee id given' do
        patch :update, params.merge(invalid_employees_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end

      it 'returns 422 when parameters not given' do
        params = { id: '12345678-1234-1234-1234-123456789012' }
        patch :update, params

        expect(response).to have_http_status(404)
      end
    end
  end
end
