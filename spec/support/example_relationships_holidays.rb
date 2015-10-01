RSpec.shared_examples 'example_relationships_holidays' do |settings|
  include_context 'shared_context_headers'
  let(:resource_name) { settings[:resource_name] }
  let(:resource_id) { "#{settings[:resource_name]}_id" }

  let!(:resource) { FactoryGirl.create(resource_name, account: account) }
  let!(:second_resource) { FactoryGirl.create(resource_name, account: account) }
  let!(:first_holiday) { FactoryGirl.create(:holiday, resource_name => second_resource) }
  let!(:second_holiday) { FactoryGirl.create(:holiday) }
  let(:params) {{ resource_id => resource.id, relationship: "holidays" }}

  describe '/#{settings[:resource_name]}/:resource_id/relationships/holidays' do

    context 'GET #show_relationship' do
      it 'list all resource holidays' do
        resource.holidays.push([first_holiday, second_holiday])
        resource.save

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

      it 'assigns holiday to resource' do
        expect {
          post :create_relationship, params.merge(first_holiday_json)
        }.to change { resource.reload.holidays.size }.from(0).to(1)
      end

      it 'changes holiday resource id' do
        expect {
          post :create_relationship, params.merge(first_holiday_json)
        }.to change { first_holiday.reload[resource_name + "_id"] }
      end

      it 'returns status 400 if relation to holidays already exists' do
        resource.holidays.push(first_holiday)
        resource.save
        post :create_relationship, params.merge(first_holiday_json)

        expect(response).to have_http_status(400)
        expect(response.body).to include "Relation exists"
      end

      it 'returns bad request when wrong holiday id given' do
        post :create_relationship, params.merge(invalid_holidays_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end

      it 'returns bad request when user want to assign not his holiday' do
        post :create_relationship, params.merge(second_holiday_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end
    end
  end
end
