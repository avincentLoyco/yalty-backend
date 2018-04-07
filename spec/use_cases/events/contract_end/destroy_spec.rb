require "rails_helper"

RSpec.describe Events::ContractEnd::Destroy do
  include_context "event destroy context"

  it_behaves_like "event destroy example"
end
