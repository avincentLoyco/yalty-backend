require "rails_helper"

RSpec.describe "Validate config/tasks.json", type: :feature do
  let(:tasks_schema) { Rails.root.join("spec", "fixtures", "schemas", "deploy_tasks.json").read }
  let(:tasks_config) { Rails.root.join("config", "deploy", "tasks.json").read }

  it "has correct structure" do
    expect(tasks_config).to match_schema(tasks_schema)
  end
end
