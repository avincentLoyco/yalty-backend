require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do
  include_examples 'example_crud_resources',
    resource_name: 'working_place'
  include_examples 'example_relationships_employees',
    resource_name: 'working_place'

  let!(:working_place) { create(:working_place, account_id: account.id) }
  let(:working_place_json) do
    {
      "type": "working-places",
      "name": "Nice office"
    }
  end

  context 'POST /working_places' do
    it 'should create working_place for current account' do
      post :create, working_place_json

      expect(response).to have_http_status(:created)
      expect(account.working_places.size).to eq(2)
      expect(account.working_places.map(&:name)).to include working_place_json[:name]
    end

    it 'should not create working_place when invalid params' do
      working_place_count = WorkingPlace.count
      post :create, { "type": "working-places" }

      expect(working_place_count).to eq(WorkingPlace.count)
      expect(response).to have_http_status(422)
    end
  end

  context 'related records assign' do
    let(:employees) { FactoryGirl.create_list(:employee, 2, account: account) }
    let(:holiday_policy) { FactoryGirl.create(:holiday_policy, account: account) }
    let(:valid_json) do
      {
        name: "testname",
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
        holiday_policy: {
          id: holiday_policy.id,
          type: "holiday_policy"
        }
      }
    end
    let(:invalid_employee_json) do
      {
        name: "testname",
        employees: [
          {
            id: employees.first.id,
            type: "employees"
          },
          {
            id: '12345678-1234-1234-1234-123456789012',
            type: "employees"
          }
        ],
        holiday_policy: {
          id: holiday_policy.id,
          type: "holiday_policy"
        }
      }
    end

    let(:invalid_holiday_policy_json) do
      {
        name: "testname",
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
        holiday_policy: {
          id: "12345678-1234-1234-1234-123456789012",
          type: "holiday_policy"
        }
      }
    end

    let(:missing_params_json) do
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
        holiday_policy: {
          id: holiday_policy.id,
          type: "holiday_policy"
        }
      }
    end

    context 'POST #create' do
      context 'valid params' do
        subject { post :create, valid_json }

        it 'creates new working place' do
          expect { subject }.to change { WorkingPlace.count }.by(1)
        end

        it 'assigns holiday_policy to working place' do
          expect(holiday_policy.working_places.size).to eq 0

          subject

          expect(holiday_policy.reload.working_places.size).to eq 1
        end

        it 'assigns employees to working place' do
          expect { subject }.to change { employees.first.reload.working_place_id }
            .and change { employees.last.reload.working_place_id }
        end

        it 'respond with success' do
          subject

          expect(response).to have_http_status(201)
        end
      end

      context 'invalid params' do
        subject { post :create, invalid_employee_json }

        context 'invalid employee id given' do
          it 'creates new working place' do
            expect { subject }.to_not change { WorkingPlace.count }
          end

          it 'does not assign holiday_policy to working place' do
            expect(holiday_policy.working_places.size).to eq 0

            subject

            expect(holiday_policy.reload.working_places.size).to eq 0
          end

          it 'does not assign employees to working place' do
            expect { subject }.to_not change { employees.first.reload.working_place_id }
          end

          it 'respond with record not found' do
            subject

            expect(response).to have_http_status(404)
          end
        end

        context 'invalid holiday_policy id given' do
          subject { post :create, invalid_holiday_policy_json }

          it 'creates new working place' do
            expect { subject }.to_not change { WorkingPlace.count }
          end

          it 'does not assign holiday_policy to working place' do
            expect(holiday_policy.working_places.size).to eq 0

            subject

            expect(holiday_policy.reload.working_places.size).to eq 0
          end

          it 'does not assign employees to working place' do
            expect { subject }.to_not change { employees.first.reload.working_place_id }
          end

          it 'respond with record not found' do
            subject

            expect(response).to have_http_status(404)
          end
        end

        context 'when invalid working place params given' do
          subject { post :create, missing_params_json }

          it 'does not create new working place' do
            expect { subject }.to_not change { WorkingPlace.count }
          end

          it 'does not assign holiday_policy to working place' do
            expect(holiday_policy.working_places.size).to eq 0

            subject

            expect(holiday_policy.reload.working_places.size).to eq 0
          end

          it 'does not assign employees to working place' do
            expect { subject }.to_not change { employees.first.reload.working_place_id }
          end

          it 'respond with param missing' do
            subject

            expect(response).to have_http_status(422)
          end
        end
      end
    end

    context 'PUT #update' do
      context 'missing params' do
        let(:params) {{ id: working_place.id }}
        subject { put :update, params.merge(missing_params_json) }

        it 'does not update working place' do
          expect { subject }.to_not change { working_place.reload.name }
        end

        it 'does not assign holiday policy' do
          expect { subject }.to_not change { working_place.reload.holiday_policy_id }
        end

        it 'does not assign employees' do
          subject

          expect(working_place.employees).to eq []
        end

        it 'respond with missing params status' do
          subject

          expect(response).to have_http_status 422
        end
      end
    end
  end

  context 'DELETE #destroy' do
    let(:working_place){ create(:working_place, account: account) }

    context 'when working place has not assigned employees' do
      it 'should delete resource' do
        expect { delete :destroy, id: working_place.id }.to change { WorkingPlace.count }.by(-1)
      end

      it 'should respond with success' do
        delete :destroy, id: working_place.id

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when working place has employees assigned' do
      let!(:employee) { create(:employee, working_place: working_place) }

      it 'should not delete resource' do
        expect { delete :destroy, id: working_place.id }.to_not change { WorkingPlace.count }
      end

      it 'should respond with lock status' do
        delete :destroy, id: working_place.id

        expect(response).to have_http_status(423)
      end
    end
  end
end
