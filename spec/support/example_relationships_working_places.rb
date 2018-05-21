RSpec.shared_examples "example_relationships_working_places" do |settings|
  include_context "shared_context_headers"
  let(:resource_name) { settings[:resource_name] }
  let(:resource_id) { "#{settings[:resource_name]}_id" }
  let!(:resource) { create(resource_name, account: account) }
  let(:resource_params) { attributes_for(settings[:resource_name]) }

  describe "working places assign" do
    let!(:first_working_place) { create(:working_place, account: account) }
    let!(:second_working_place) { create(:working_place, account: account) }
    let(:first_working_place_json) do
      {
        working_places: [
          {
            "type": "working_places",
            "id": first_working_place.id,
          },
        ],
      }
    end
    let(:second_working_place_json) do
      {
        working_places: [
          {
            "type": "working_places",
            "id": second_working_place.id,
          },
        ],
      }
    end
    let(:both_working_places_json) do
      {
        working_places: [
          {
            "type": "working_places",
            "id": first_working_place.id,
          },
          {
            "type": "working_places",
            "id": second_working_place.id,
          },
        ],
      }
    end

    let(:invalid_working_places_json) do
      {
        working_places: [
          {
            "type": "working_places",
            "id": "12345678-1234-1234-1234-123456789012",
          },
        ],
      }
    end

    context "POST #create" do
      subject { post :create, params }

      context "assigns employee to working place" do
        let(:params) { resource_params.merge(first_working_place_json) }

        it "should change working place resource id" do
          expect { subject }.to change { first_working_place.reload.send(resource_name + "_id") }
        end

        context "response" do
          before { subject }

          it { expect(response).to have_http_status(:success) }
        end
      end

      context "assigns two employees to working place" do
        let(:params) { resource_params.merge(both_working_places_json) }

        it "should change first working place resource id" do
          expect { subject }.to change { first_working_place.reload.send(resource_name + "_id") }
        end

        it "should change second working place resource id" do
          expect { subject }.to change { second_working_place.reload.send(resource_name + "_id") }
        end

        context "response" do
          before { subject }

          it { expect(response).to have_http_status(:success) }
        end
      end

      context "it returns bad request when wrong employee id given" do
        let(:params) { resource_params.merge(invalid_working_places_json) }

        it "returns bad request" do
          subject

          expect(response).to have_http_status(404)
          expect(response.body).to include "Record Not Found"
        end
      end
    end

    context "PATCH #update" do
      let(:params) {{ id: resource.id }}

      it "assigns working_place to resource" do
        expect {
          patch :update, params.merge(first_working_place_json)
        }.to change { resource.reload.working_places.size }.from(0).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it "replaces working_place in resources when new id given" do
        resource.working_places.push(first_working_place, second_working_place)
        resource.save
        expect {
          patch :update, params.merge(second_working_place_json)
        }.to change { resource.reload.working_places.size }.from(2).to(1)

        expect(response).to have_http_status(:no_content)
      end

      it "allows for adding few working_places at time when new ids given" do
        expect {
          patch :update, params.merge(both_working_places_json)
        }.to change { resource.reload.working_places.size }.from(0).to(2)

        expect(response).to have_http_status(:no_content)
      end

      it "returns bad request when wrong resource id given" do
        params = { id: "12345678-1234-1234-1234-123456789012" }
        patch :update, params.merge(first_working_place_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end

      it "returns bad request when wrong working_place id given" do
        patch :update, params.merge(invalid_working_places_json)

        expect(response).to have_http_status(404)
        expect(response.body).to include "Record Not Found"
      end
    end
  end
end
