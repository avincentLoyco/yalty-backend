# frozen_string_literal: true

RSpec.describe UseCase do
  class FakeUseCase < UseCase
    def call
      run_callback(:success, :well_done)
    end
  end

  describe "#call" do
    let(:use_case) { FakeUseCase.new }

    it "runs callback" do
      use_case.on(:success) { |message| message }

      expect(use_case.call).to eq :well_done
    end
  end

  describe ".call" do
    let(:messenger) { double }

    before do
      allow(messenger).to receive(:notify)
    end

    it "runs callback on instance" do
      FakeUseCase.call do |fake|
        fake.on(:success) do |message|
          messenger.notify(message)
        end
      end

      expect(messenger).to have_received(:notify).with(:well_done)
    end
  end
end
