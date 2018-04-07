require "rails_helper"

RSpec.describe Events::WorkContract::Update do
  include_context "event update context"

  it_behaves_like "event update example"
end
