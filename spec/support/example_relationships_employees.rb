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
    let(:resource_param) { attributes_for(settings[:resource_name]).keys.first }
    let(:without_employee_json) do
      {
        resource_param => 'test'
      }
    end

    context 'post #create' do
      subject { post :create, params }

      context 'assigns employee to working place' do
        let(:params) { resource_params.merge(first_employee_json) }

        it { expect { subject }.to change { first_employee.reload.send(resource_name + "_id") } }

        context 'response' do
          before { subject }

          it { expect(response).to have_http_status(:success) }
        end
      end

      context 'assigns two employees to working place' do
        let(:params) { resource_params.merge(both_employees_json) }

        it { expect { subject }.to change { first_employee.reload.send(resource_name + "_id") } }
        it { expect { subject }.to change { second_employee.reload.send(resource_name + "_id") } }

        context 'response' do
          before { subject }

          it { expect(response).to have_http_status(:success) }
        end
      end

      context 'it returns bad request when wrong employee ids given' do
        let(:params) { resource_params.merge(invalid_employees_json) }

        it 'returns bad request' do
          subject

          expect(response).to have_http_status(404)
          expect(response.body).to include "Record Not Found"
        end
      end
    end

    context 'PUT #update' do
      let(:params) { resource_params.merge({ id: resource.id }) }

      it 'assigns employee to working place when new id given' do
        expect {
          put :update, params.merge(first_employee_json)
        }.to change { resource.reload.employees.size }.from(0).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it 'overwrites employees set when new id given' do
        resource.employees.push(first_employee, second_employee)
        resource.save

        expect(resource.employees.count).to eq(2)
        expect {
          put :update, params.merge(second_employee_json)
        }.to change { resource.employees.count }.from(2).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it 'overwrties all employees from resource when empty array send' do
        resource.employees.push(first_employee, second_employee)
        resource.save

        expect(resource.employees.count).to eq(2)
        expect {
          put :update, params.merge(empty_employee_array_json)
        }.to change { resource.reload.employees.size }.from(2).to(0)

        expect(response).to have_http_status(:no_content)
      end

      it 'does not overwrite employees when params without employees send' do
        resource.employees.push(first_employee, second_employee)
        resource.save

        expect(resource.employees.count).to eq(2)
        put :update, params.merge(without_employee_json)

        expect(resource.reload[resource_param]).to eq('test')
        expect(resource.reload.employees.count).to eq (2)

        expect(response).to have_http_status(:no_content)
      end

      it 'allows for adding few employees at time when new ids given' do
        expect {
          put :update, params.merge(both_employees_json)
        }.to change { resource.reload.employees.size }.from(0).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns status 204 if employee already exists' do
        resource.employees.push(first_employee)
        resource.save

        expect(resource.employees.count).to eq(1)
        put :update, params.merge(first_employee_json)

        expect(response).to have_http_status(204)
        expect(resource.employees.count).to eq(1)
      end

      it 'returns bad request when wrong working place id given' do
        params = resource_params.merge({ id: '12345678-1234-1234-1234-123456789012' })
        put :update, params.merge(first_employee_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end

      it 'returns bad request when wrong employee id given' do
        put :update, params.merge(invalid_employees_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end
    end
  end
end
