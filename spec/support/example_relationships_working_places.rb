RSpec.shared_examples 'example_relationships_working_places' do |settings|
  include_context 'shared_context_headers'
  let(:resource_name) { settings[:resource_name] }
  let(:resource_id) { "#{settings[:resource_name]}_id" }

  let!(:resource) { create(resource_name, account: account) }

  describe "/#{settings[:resource_name]}/:resource_id/relationships/working_places" do
    let!(:first_working_place) { create(:working_place, account: account) }
    let!(:second_working_place) { create(:working_place, account: account) }
    let(:params) {{ resource_id => resource.id, relationship: "working_places" }}

    let(:first_working_place_json) do
      {
        "data": [
          { "type": "working_places",
            "id": first_working_place.id }
        ]
      }
    end
    let(:second_working_place_json) do
      {
        "data": [
          { "type": "working_places",
            "id": second_working_place.id }
        ]
      }
    end
    let(:both_working_places_json) do
      {
        "data": [
          { "type": "working_places",
            "id": first_working_place.id },
          { "type": "working_places",
            "id": second_working_place.id }
        ]
      }
    end

    let(:invalid_working_places_json) do
      {
        "data": [
          { "type": "working_places",
            "id": '12345678-1234-1234-1234-123456789012' }
        ]
      }
    end

    context 'post #create_relationship' do
      it 'assigns working_place to working place when new id given' do
        expect {
          post :create_relationship, params.merge(first_working_place_json)
        }.to change { resource.reload.working_places.size }.from(0).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it 'adds working_place to working place working_places when new id given' do
        resource.working_places.push(first_working_place)
        resource.save
        expect {
          post :create_relationship, params.merge(second_working_place_json)
        }.to change { resource.reload.working_places.size }.from(1).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it 'allows for adding few working_places at time when new ids given' do
        expect {
          post :create_relationship, params.merge(both_working_places_json)
        }.to change { resource.reload.working_places.size }.from(0).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns status 400 if working_place already exists' do
        resource.working_places.push(first_working_place)
        resource.save

        post :create_relationship, params.merge(first_working_place_json)

        expect(response).to have_http_status(400)
        expect(response.body).to include "Relation exists"
      end

      it 'returns bad request when wrong working place id given' do
        params = { resource_id => '12345678-1234-1234-1234-123456789012',
                   relationship: "working_places" }
        post :create_relationship, params.merge(first_working_place_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end

      it 'returns bad request when wrong working_place id given' do
        post :create_relationship, params.merge(invalid_working_places_json)

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
      it 'delete working_place from relationship if exist' do
        resource.working_places.push(first_working_place)
        resource.save
        expect {
          delete :destroy_relationship, params.merge(keys: first_working_place.id)
        }.to change { resource.reload.working_places.size }.from(1).to(0)

        expect(response).to have_http_status(:no_content)
      end

      it 'return 404 when wrong working_place id given' do
        post :destroy_relationship, params.merge(
          keys: '12345678-1234-1234-1234-123456789012'
        )

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record not found"
      end
    end

    context 'get #show_relationship' do
      it 'list all working place working_places' do
        resource.working_places.push([first_working_place, second_working_place])
        resource.save

        get :show_relationship, params

        expect(response).to have_http_status(:success)
        expect(response.body).to include first_working_place.id
        expect(response.body).to include second_working_place.id
      end
    end
  end
end
