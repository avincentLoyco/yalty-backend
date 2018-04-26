RSpec.shared_context "shared_context_timecop_helper" do
  around(:each) do |example|
    travel_to Date.new(2016, 1, 1) do
      example.run
    end
  end
end
