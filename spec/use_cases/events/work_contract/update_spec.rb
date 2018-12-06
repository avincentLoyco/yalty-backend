require "rails_helper"

RSpec.describe Events::WorkContract::Update do
  include_context "event update context"
  include_context "end of contract balance handler context"

  let(:subject) do
    described_class
      .new(
        update_event_service: update_event_service_class_mock,
        find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
        create_eoc_balance: create_eoc_balance_mock,
        find_first_eoc_event_after: find_first_eoc_event_after_mock,
      )
      .call(event, params)
  end

  it_behaves_like "event update example"
  it_behaves_like "end of contract balance handler for an event"
end
