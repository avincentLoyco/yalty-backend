require 'rails_helper'

RSpec.describe API::V1::WorkingPlacesController, type: :controller do
  include_context 'shared_context_geoloc_helper'
  include_context 'example_authorization',
    resource_name: 'working_place'
  include_examples 'example_crud_resources',
    resource_name: 'working_place'
  include_examples 'shared_context_active_and_inactive_resources',
    resource_class: WorkingPlace.model_name,
    join_table_class: EmployeeWorkingPlace.model_name

  let(:first_working_place) { create(:working_place, account: account) }
  let(:presence_policy) { create(:presence_policy, account: account) }
  let!(:employee) { create(:employee, account: Account.current, employee_working_places: [ewp]) }
  let(:ewp) do
    create(:employee_working_place,
      working_place: first_working_place, effective_at: Time.now - 6.months)
  end

  let(:country) { 'Switzerland' }
  let(:country_code) { 'CH' }
  let(:state_name) { 'Zurich' }
  let(:state_code) { 'ZH' }
  let(:timezone) { 'Europe/Zurich' }

  context 'GET #index' do
    subject { get :index }

    let(:working_place_with_employees) do
      JSON.parse(response.body).select { |wp| wp['employees'].present? }.first
    end

    context 'response' do
      before { subject }

      it { is_expected.to have_http_status(200) }
      it { expect_json_sizes(1) }
      it do
        expect_json_keys('*', [:id, :type, :name, :employees, :country,
                               :city, :postalcode, :street, :street_number, :additional_address, :deletable])
      end
      it { expect(working_place_with_employees['deletable']).to be false }
    end
  end

  context 'GET #show' do
    subject { get :show, id: working_place.id }

    let!(:working_place) { create(:working_place, account: Account.current) }

    context 'when working_place does not have related employee working places' do
      context 'response' do
        before { subject }

        it { expect_json('employees', []) }
        it { expect_json('deletable', true) }
      end
    end

    context 'when working place has assigned employee working places' do
      before { ewp.update!(working_place: working_place) }

      context 'response' do
        before { subject }

        it { expect_json('employees.0',
          id: employee.id, type: 'employee', assignation_id: ewp.id)
        }
        it { expect_json('deletable', false) }
      end
    end
  end

  context 'POST #create' do
    subject { post :create, valid_data_json }

    let(:name) { 'test' }
    let(:state_param) { state_code }

    let(:valid_data_json) do
      {
        name: name,
        type: 'working_place',
        state: state_param,
        country: country_code
      }
    end

    shared_examples 'Invalid Data' do
      context 'it does not create or update records' do
        it { expect { subject }.to_not change { WorkingPlace.count } }
        it { expect { subject }.to_not change { account.reload.working_places.count } }
      end
    end

    context 'including country that has region validation' do
      context 'and state that doesn\'t match existing holiday policy' do
        it { expect { subject }.to change { account.reload.working_places.count }.by(1) }
        it { expect { subject }.to change { account.reload.holiday_policies.count }.by(1) }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(201) }

          it { expect_json('state', 'ZH') }
          it { expect_json('country', 'CH') }
          it { expect_json('timezone', 'Europe/Zurich') }
        end
      end

      context 'and state that match existing holiday policy' do
        let!(:holiday_policy) do
          create(:holiday_policy, account: account, region: state_code, country: country_code)
        end

        it { expect { subject }.to change { account.reload.working_places.count }.by(1) }
        it { expect { subject }.to_not change { HolidayPolicy.count } }
        it { expect { subject }.to change { holiday_policy.reload.working_places.count }.by(1) }

        context 'reponse' do
          before { subject }

          it { is_expected.to have_http_status(201) }

          it { expect_json('state', 'ZH') }
          it { expect_json('country', 'CH') }
          it { expect_json('timezone', 'Europe/Zurich') }
        end
      end

      context 'and without state' do
        let(:state_name) { nil }
        let(:state_code) { nil }

        it { expect { subject }.to_not change { WorkingPlace.count } }
        it { expect { subject }.to_not change { HolidayPolicy.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(422) }
        end
      end
    end

    context 'with country that doen\'t have region validation' do
      let(:state_name) { nil }
      let(:state_code) { nil }
      let(:country) { 'Poland'}
      let(:country_code) { 'PL'}
      let(:timezone) { 'Europe/Warsaw' }

      context 'response' do
        before { subject }

        it do
          expect_json_types(name: :string, id: :string, type: :string, country: :string,
                            city: :string_or_null, postalcode: :string_or_null,
                            street: :string_or_null, street_number: :string_or_null,
                            additional_address: :string_or_null, timezone: :string_or_null)
        end
      end

      context 'with state specified' do
        let(:state_param) { 'Podkarpacie' }
        let(:state_name) { 'Podkarpacie Voivodeship' }
        let(:state_code) { 'Podkarpacie Voivodeship' }

        it { expect { subject }.to change { WorkingPlace.count } }
        it { expect { subject }.to_not change { HolidayPolicy.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(201) }

          it { expect_json('state', 'Podkarpacie') }
          it { expect_json('country', 'PL') }
          it { expect_json('timezone', 'Europe/Warsaw') }
        end
      end

      context 'with state not specified' do
        it { expect { subject }.to change { WorkingPlace.count } }
        it { expect { subject }.to_not change { HolidayPolicy.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(201) }

          it { expect_json('state', nil) }
          it { expect_json('country', 'PL') }
          it { expect_json('timezone', 'Europe/Warsaw') }
        end
      end

      context 'without address'  do
        let(:state_name) { nil }
        let(:state_code) { nil }
        let(:country) { nil }
        let(:country_code) { nil }
        let(:timezone) { nil }

        it { expect { subject }.to change { WorkingPlace.count }.by(1) }
        it { expect { subject }.to_not change { HolidayPolicy.count } }

        context 'response' do
          before { subject }

          it { is_expected.to have_http_status(201) }

          it { expect_json('state', nil) }
          it { expect_json('country', nil) }
          it { expect_json('timezone', nil) }
        end
      end
    end

    context 'with invalid params' do
      context 'without all required params' do
        subject { post :create, missing_data_json }

        let(:missing_data_json) { valid_data_json.tap { |json| json.delete(:name) } }

        it_behaves_like 'Invalid Data'

        it { is_expected.to have_http_status(422) }

        context 'response' do
          before { subject }

          it { expect_json(regex('missing')) }
        end
      end

      context 'with name param that is empty' do
        let(:name) { '' }

        it { is_expected.to have_http_status(422) }

        it_behaves_like 'Invalid Data'

        context 'response' do
          before { subject }

          it { expect_json(regex('must be filled')) }
        end
      end
    end
  end

  context 'PUT #update' do
    subject { put :update, valid_data_json }

    let(:working_place) { create(:working_place, country: country, city: city, account: account) }

    let(:id) { working_place.id }
    let(:name) { 'test' }
    let(:country) { 'Switzerland' }

    let(:valid_data_json) do
      {
        id: id,
        name: name,
        type: 'working_place',
        country: country
      }
    end

    shared_examples 'Invalid Data' do
      context 'it does not update and assign records' do
        it { expect { subject }.to_not change { working_place.reload.name } }
        it { expect { subject }.to_not change { working_place.reload.holiday_policy_id } }
      end
    end

    context 'with valid data' do
      it { expect { subject }.to change { working_place.reload.name } }
      it { expect { subject }.to change { working_place.reload.holiday_policy_id } }

      it { is_expected.to have_http_status(204) }

      context 'with country without region validation' do
        let(:country) { 'Poland' }
        let(:city) { 'Warsaw' }
        let(:country_code) { 'PL' }

        it { expect { subject }.to change { working_place.reload.name } }

        it { is_expected.to have_http_status(204) }
      end
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

          it { expect_json(regex('must be filled')) }
        end
      end

      context 'with invalid related records ids' do
        context 'with invalid working place id' do
          let(:id) { '1' }

          it_behaves_like 'Invalid Data'

          it { is_expected.to have_http_status(404) }

          context 'response' do
            before { subject }

            it { expect_json(regex('Record Not Found')) }
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
        it { expect { subject }.to_not change { WorkingPlace.count } }
        it { is_expected.to have_http_status(423) }

        context 'response' do
          before { subject }

          it { expect_json(regex('Locked')) }
        end
      end
    end
  end
end
