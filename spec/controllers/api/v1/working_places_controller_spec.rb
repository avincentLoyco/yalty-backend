require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do

  include_context 'example_authorization',
    resource_name: 'working_place'
  include_examples 'example_crud_resources',
    resource_name: 'working_place'
  include_examples 'shared_context_active_and_inactive_resources',
    resource_class: WorkingPlace.model_name,
    join_table_class: EmployeeWorkingPlace.model_name

  let(:first_working_place) { create(:working_place, account: account) }
  let(:holiday_policy) { create(:holiday_policy, account: account) }
  let(:presence_policy) { create(:presence_policy, account: account) }
  let!(:employee) { create(:employee, account: Account.current, employee_working_places: [ewp]) }
  let(:ewp) do
    create(:employee_working_place,
      working_place: first_working_place, effective_at: Time.now - 6.months)
  end

  # before :each do
  #   loc = Geokit::GeoLoc.new
  #   loc.city = 'Zurich'
  #   loc.country = 'Switzerland'
  #   allow_any_instance_of(WorkingPlace).to receive(:place_info) { loc }
  #   binding.pry
  # end

  context 'GET #index' do
    subject { get :index }
    before { subject }

    it { is_expected.to have_http_status(200) }
    it { expect_json_sizes(1) }
    it do
      expect_json_keys('*', [:id, :type, :name, :employees, :holiday_policy, :country, :state,
                             :city, :postalcode, :street, :street_number, :additional_address])
    end
  end

  context 'GET #show' do
    subject { get :show, id: working_place.id }
    let!(:working_place) { create(:working_place, account: Account.current) }

    context 'when working_place does not have related employee working places' do
      before { subject }

      it { expect_json('employees', []) }
    end

    context 'when working place has assigned employee working places' do
      before do
        ewp.update!(working_place: working_place)
        subject
      end

      it { expect_json('employees.0',
        id: employee.id, type: 'employee', assignation_id: ewp.id)
      }
    end
  end

  context 'POST #create' do
    let(:name) { 'test' }
    let(:country) { 'Switzerland' }
    let(:city) { 'Zurich' }
    let(:state) { 'Some State' }
    let(:holiday_policy_id) { holiday_policy.id }
    let(:valid_data_json) do
      {
        name: name,
        type: 'working_place',
        holiday_policy: {
          id: holiday_policy_id,
          type: 'holiday_policy'
        },
        country: country,
        city: city,
        state: state
      }
    end
    shared_examples 'Invalid Data' do
      context 'it does not create or update records' do
        it { expect { subject }.to_not change { WorkingPlace.count } }
        it { expect { subject }.to_not change { account.reload.working_places.count } }
        it { expect { subject }.to_not change { holiday_policy.working_places.count } }
      end
    end

    subject { post :create, valid_data_json }

    context 'with valid params' do
      it { expect { subject }.to change { WorkingPlace.count }.by(1) }
      it { expect { subject }.to change { account.reload.working_places.count }.by(1) }
      it { expect { subject }.to change { holiday_policy.working_places.count }.by(1) }

      it { is_expected.to have_http_status(201) }

      context 'response' do
        before { subject }

        it do
          expect_json_types(name: :string, id: :string, type: :string, country: :string,
                            city: :string, state: :string_or_null, postalcode: :string_or_null,
                            street: :string_or_null, street_number: :string_or_null,
                            additional_address: :string_or_null)
        end
      end

      context 'null holiday policy' do
        before { valid_data_json[:holiday_policy] = nil }

        it { expect { subject }.to change { WorkingPlace.count }.by(1) }
        it { expect { subject }.to change { account.reload.working_places.count }.by(1) }
        it { expect { subject }.not_to change { holiday_policy.working_places.count } }
        it { is_expected.to have_http_status(201) }
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
        ## POPRAWA array
        context 'without name' do
          let(:name) { '' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(422) }

          context 'response' do
            before { subject }

            it { expect_json(regex('must be filled')) }
          end
        end
        context 'without country' do
          let(:country) { '' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(422) }

          context 'response' do
            before { subject }

            it { expect_json(regex('must be filled')) }
          end
        end
        context 'with param that fails regex validation' do
          let(:state) { 'Some State1' }
          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(422) }

          context 'response' do
            before { subject }

            it { expect_json(regex('only nondigit')) }
          end
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
      let(:valid_data_json) do
        {
          id: id,
          name: name,
          type: 'working_place',
          holiday_policy: {
            id: holiday_policy_id,
            type: 'holiday_policy'
          },
          country: 'Switzerland',
          city: 'Zurich'
        }
      end

      shared_examples 'Invalid Data' do
        context 'it does not update and assign records' do
          it { expect { subject }.to_not change { working_place.reload.name } }
          it { expect { subject }.to_not change { working_place.reload.holiday_policy_id } }
        end
      end

      subject { put :update, valid_data_json }

      context 'with valid data' do
        it { expect { subject }.to change { working_place.reload.name } }
        it { expect { subject }.to change { working_place.reload.holiday_policy_id } }

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

            it { expect_json(regex("must be filled")) }
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
      let!(:employee_working_place) do
        create(:employee_working_place, working_place: working_place)
      end

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
