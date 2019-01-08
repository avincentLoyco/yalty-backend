require "rails_helper"

RSpec.describe Events::Default::Create do

  include_context "event create use case"

  it_behaves_like "event create example"
end
