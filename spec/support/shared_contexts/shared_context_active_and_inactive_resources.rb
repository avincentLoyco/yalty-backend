RSpec.shared_context "shared_context_active_and_inactive_resources" do |settings|
  include_context "shared_context_account_helper"

  context "GET #index" do
    subject { get :index, { status: status } }

    if settings[:resource_class].name == "TimeOffPolicy"
      let(:category) { create(:time_off_category, account: account) }
      let(:resource) { create(resource_sym, time_off_category: category) }
      let(:new_resource) { create(resource_sym, time_off_category: category) }
      let!(:not_assigned_resources) { create_list(resource_sym, 2, time_off_category: category) }
      let!(:other_account_resource) { create(resource_sym) }
    elsif settings[:resource_class].name == "PresencePolicy"
      let(:resource) { create(resource_sym, :with_presence_day, account: account) }
      let(:new_resource) { create(resource_sym, :with_presence_day, account: account) }
      let!(:other_account_resource) { create(resource_sym) }
      let!(:not_assigned_resources) do
        create_list(resource_sym, 2, :with_presence_day, account: account)
      end
    else
      let!(:other_account_resource) { create(resource_sym) }
      let(:resource) { create(resource_sym, account: account) }
      let(:new_resource) { create(resource_sym, account: account) }
      let!(:not_assigned_resources) { create_list(resource_sym, 2, account: account) }
    end

    let(:resource_sym) { settings[:resource_class].singular.to_sym }
    let(:join_table_sym) { settings[:join_table_class].singular.to_sym }
    let(:join_table) do
      create(join_table_sym, resource_sym => resource, effective_at: Time.now - 1.year)
    end
    let!(:employee) do
      create(:employee, settings[:join_table_class].plural.to_sym => [join_table], account: account)
    end

    context "with status active param" do
      let(:status) { "active" }

      context "when there are no active resources" do
        before do
          employee.destroy!
          settings[:resource_class].name.constantize.all.delete_all
          subject
        end

        it { is_expected.to have_http_status(200) }
        it { expect(response.body).to eq [].to_json }
      end

      context "when all resources are active" do
        before { subject }

        it { is_expected.to have_http_status(200) }

        it { expect(response.body).to include employee.id }
        it { expect(response.body).to include not_assigned_resources.first.id }
        it { expect(response.body).to include not_assigned_resources.last.id }
        it { expect(response.body).to include resource.id }
        it { expect(response.body).to_not include other_account_resource.id }
      end

      context "when not all resources are active" do
        before do
          create(join_table_sym,
            effective_at: Time.now - 1.day, employee: employee, resource_sym => new_resource)
        end

        context "when resource is inactive for one employee and active for other" do
          before do
            new_join_table = create(join_table_sym, resource_sym => resource)
            create(:employee, account: account,
              settings[:join_table_class].plural.to_sym => [new_join_table])
            subject
          end

          it { is_expected.to have_http_status(200) }

          it { expect(response.body).to include not_assigned_resources.first.id }
          it { expect(response.body).to include not_assigned_resources.last.id }
          it { expect(response.body).to include resource.id }
          it { expect(response.body).to include new_resource.id }
          it { expect(response.body).to_not include other_account_resource.id }
        end

        context "when resource is inactive for all employees" do
          before { subject }

          it { is_expected.to have_http_status(200) }

          it { expect(response.body).to include not_assigned_resources.first.id }
          it { expect(response.body).to include not_assigned_resources.last.id }
          it { expect(response.body).to include new_resource.id }

          it { expect(response.body).to_not include other_account_resource.id }
        end
      end
    end

    context "with status inactive param" do
      let(:status) { "inactive" }

      context "when there are no inactive resources" do
        before { subject }

        it { is_expected.to have_http_status(200) }

        it { expect(response.body).to_not include resource.id }
        it { expect(response.body).to_not include other_account_resource.id }
      end

      context "when there are inactive resources" do
        before do
          create(join_table_sym,
            effective_at: Time.now - 1.day, employee: employee, resource_sym => new_resource)
          subject
        end

        it { is_expected.to have_http_status(200) }

        it { expect(response.body).to_not include new_resource.id }
        it { expect(response.body).to_not include other_account_resource.id }
      end
    end
  end
end
