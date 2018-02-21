RSpec.shared_context "shared_context_join_tables_controller" do |settings|
  let(:resource_name) { "#{settings[:resource]}_id".to_sym }

  if settings[:resource].eql?(:time_off_policy)
    let(:category) { create(:time_off_category, account: account) }
    let(:resource) { create(settings[:resource], time_off_category: category) }
  elsif settings[:resource].eql?(:presence_policy)
    let(:resource) { create(settings[:resource], :with_presence_day, account: account) }
  else
    let(:resource) { create(settings[:resource], account: account) }
  end
  let!(:join_tables) do
    [1.year.ago, 1.year.since].map do |date|
      create(settings[:join_table],
        effective_at: date, employee: employee, settings[:resource] => resource)
    end
  end
  let!(:contract_end) do
    create(:employee_event,
      employee: employee, effective_at: Date.today, event_type: "contract_end")
  end
  let!(:rehired_event) do
    create(:employee_event,
      employee: employee, effective_at: 1.year.since, event_type: "hired")
  end
  let(:reset_resource) { employee.send(settings[:join_table].to_s.pluralize).with_reset.first }

  describe "GET #index" do
    subject { get :index, resource_name => resource.id }

    it { is_expected.to have_http_status(200) }
    it "takes contract end date into consideration" do
      subject

      parsed_response = JSON.parse(response.body)
      expect(parsed_response.first["effective_till"]).to eq contract_end.effective_at.to_s
    end
  end

  describe "POST #create" do
    before { params.merge!(order_of_start_day: 1) if settings[:resource].eql?(:presence_policy) }
    subject { post :create, params }

    let(:params) do
      {
        employee_id: employee.id,
        effective_at: reset_resource.effective_at,
        resource_name => resource.id
      }
    end

    it { is_expected.to have_http_status(422) }
    it { expect { subject }.to_not change { reset_resource.class.exists?(reset_resource.id) } }
    it do
      subject

      expect(response.body).to include "Can not assign in reset resource effective at"
    end
  end

  describe "PUT #update" do
    before { params.merge!(order_of_start_day: 1) if settings[:resource].eql?(:presence_policy) }
    subject { put :update, params }

    let(:params) do
      {
        id: reset_resource.id,
        effective_at: 2.years.since
      }
    end

    it { is_expected.to have_http_status(404) }
    it { expect { subject }.to_not change { reset_resource.reload.effective_at } }
  end

  describe "DELETE #destroy" do
    subject { delete :destroy, id: reset_resource.id }

    it { is_expected.to have_http_status(404) }
    it { expect { subject }.to_not change { join_tables.first.class.count } }
    it { expect { subject }.to_not change { join_tables.first.class.exists?(reset_resource.id) } }
  end
end
