require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do
  include_examples 'example_authorization',
    resource_name: 'working_place'
  include_examples 'example_crud_resources',
    resource_name: 'working_place'

  let(:holiday_policy) { create(:holiday_policy, account: account) }
  let(:presence_policy) { create(:presence_policy, account: account) }
  let(:time_off_policy) { create(:time_off_policy) }

  context 'POST #create' do
    let(:name) { 'test' }
    let(:holiday_policy_id) { holiday_policy.id }
    let(:presence_policy_id) { presence_policy.id }
    let(:time_off_policy_id) { time_off_policy.id }
    let(:valid_data_json) do
      {
        name: name,
        type: 'working_place',
        holiday_policy: {
          id: holiday_policy_id,
          type: 'holiday_policy',
        },
        presence_policy: {
          id: presence_policy_id,
          type: 'presence_policy'
        },
        {
          id: time_off_policy_id,
          type: 'time_off_policy'
        }
      }
    end
    shared_examples 'Invalid Data' do
      context 'it does not create or update records' do
        it { expect { subject }.to_not change { WorkingPlace.count } }
        it { expect { subject }.to_not change { account.reload.working_places.count } }
        it { expect { subject }.to_not change { holiday_policy.working_places.count } }
        it { expect { subject }.to_not change { presence_policy.working_places.count } }
        it { expect { subject }.to_not change { time_off_policy.working_places.count } }
      end
    end

    subject { post :create, valid_data_json }

    context 'with valid params' do
      it { expect { subject }.to change { WorkingPlace.count }.by(1) }
      it { expect { subject }.to change { account.reload.working_places.count }.by(1) }
      it { expect { subject }.to change { holiday_policy.working_places.count }.by(1) }
      it { expect { subject }.to change { presence_policy.working_places.count }.by(1) }
      it { expect { subject }.to change { time_off_policy.working_places.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response' do
        before { subject }

        it { expect_json_types(name: :string, id: :string, type: :string) }
      end
    end

    context 'with invalid params' do
      context 'without all required params' do
        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
        subject { post :create, missing_data_json }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }

        context 'response' do
          before { subject }

          it { expect_json(regex('missing')) }
        end
      end

      context 'with params that are not valid' do
        let(:name) { '' }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }

        context 'response' do
          before { subject }

          it { expect_json(regex("can't be blank")) }
        end
      end

      context 'with invalid related records ids' do
        context 'with invalid holiday policy id' do
          let(:holiday_policy_id) { '1' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }

          context 'response' do
            before { subject }

            it { expect_json(regex("Record Not Found")) }
          end
        end

        context 'with invalid presence policy id' do
          let(:presence_policy_id) { '1' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }

          context 'response' do
            before { subject }

            it { expect_json(regex("Record Not Found")) }
          end
        end

        context 'with invalid time off policies' do
          let(:time_off_policy_id) { '1' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }

          context 'response' do
            before { subject }

            it { expect_json(regex("Record Not Found")) }
          end
        end
      end
    end
  end

  context 'PUT #update' do
    context 'valid params' do
      let(:working_place) { create(:working_place, account: account) }
      let(:name) { 'test' }
      let(:id) { working_place.id }
      let(:holiday_policy_id) { holiday_policy.id }
      let(:presence_policy_id) { presence_policy.id }
      let(:time_off_policy_id) { time_off_policy.id }
      let(:valid_data_json) do
        {
          id: id,
          name: name,
          type: 'working_place',
          holiday_policy: {
            id: holiday_policy_id,
            type: 'holiday_policy',
          },
          presence_policy: {
            id: presence_policy_id,
            type: 'presence_policy'
          },
          time_off_policies: [
            {
              id: time_off_policy_id,
              type: 'time_off_policy'
            }
          ]
        }
      end

      shared_examples 'Invalid Data' do
        context 'it does not update and assign records' do
          it { expect { subject }.to_not change { working_place.reload.name } }
          it { expect { subject }.to_not change { working_place.reload.holiday_policy_id } }
          it { expect { subject }.to_not change { working_place.reload.presence_policy_id } }
          it { expect { subject }.to_not change { working_place.reload.time_off_policies } }
        end
      end

      subject { put :update, valid_data_json }

      context 'with valid data' do
        it { expect { subject }.to change { working_place.reload.name } }
        it { expect { subject }.to change { working_place.reload.holiday_policy_id } }
        it { expect { subject }.to change { working_place.reload.presence_policy_id } }
        it { expect { subject }.to change { working_place.reload.time_off_policies.pluck(:id) } }

        it { is_expected.to have_http_status(204) }
      end

      context 'with holiday_policy null send' do
        let!(:holiday_policy) do
          create(:holiday_policy, account: account, working_places: [working_place])
        end
        subject { put :update, valid_data_json.merge(holiday_policy: nil) }

        it { is_expected.to have_http_status(204) }
        it { expect { subject }.to change { working_place.reload.holiday_policy_id }.to(nil) }
      end

      context 'with invalid data' do
        context 'without all required params' do
          let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }
          subject { post :create, missing_data_json }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(422) }

          context 'response' do
            before { subject }

            it { expect_json(regex('missing')) }
          end
        end

        context 'with params that are not valid' do
          let(:name) { '' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(422) }

          context 'response' do
            before { subject }

            it { expect_json(regex("can't be blank")) }
          end
        end

        context 'with invalid related records ids' do
          context 'with invalid working place id' do
            let(:id) { '1' }

            it_behaves_like 'Invalid Data'

            it { is_expected.to have_http_status(404) }

            context 'response' do
              before { subject }

              it { expect_json(regex("Record Not Found")) }
            end
          end

          context 'with invalid holiday policy id' do
            let(:holiday_policy_id) { '1' }

            it_behaves_like 'Invalid Data'

            it { is_expected.to have_http_status(404) }

            context 'response' do
              before { subject }

              it { expect_json(regex("Record Not Found")) }
            end
          end

          context 'with invalid presence policy id' do
            let(:presence_policy_id) { '1' }

            it_behaves_like 'Invalid Data'

            it { is_expected.to have_http_status(404) }

            context 'response' do
              before { subject }

              it { expect_json(regex("Record Not Found")) }
            end
          end

          context 'with invalid time off policies' do
            let(:time_off_policy_id) { '1' }

            it_behaves_like 'Invalid Data'

            it { is_expected.to have_http_status(404) }

            context 'response' do
              before { subject }

              it { expect_json(regex("Record Not Found")) }
            end
          end
        end
      end
    end
  end

  context 'DELETE #destroy' do
    let!(:working_place) { create(:working_place, account: account) }
    subject { delete :destroy, id: working_place.id }

    context 'when working place has not assigned employees' do
      it { expect { subject }.to change { WorkingPlace.count }.by(-1) }
      it { is_expected.to have_http_status(204) }
    end

    context 'when working place has employees assigned' do
      let!(:employee) { create(:employee, working_place: working_place) }

      context 'when working place has employees assigned' do
        it { expect { subject  }.to_not change { WorkingPlace.count } }
        it { is_expected.to have_http_status(423) }

        context 'response' do
          before { subject }

          it { expect_json(regex('Locked')) }
        end
      end
    end
  end
end
