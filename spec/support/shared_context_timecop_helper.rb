RSpec.shared_context 'shared_context_timecop_helper' do
  before do
    Timecop.freeze(2016, 1, 1, 0, 0)
  end

  after do
    Timecop.return
  end
end
