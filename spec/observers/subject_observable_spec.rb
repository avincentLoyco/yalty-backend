# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubjectObservable do
  class FakeClassObservable
    include SubjectObservable
  end

  let(:entity)   { FakeClassObservable.new }
  let(:observer) { instance_double("FakeObserver", update: true) }

  describe "#initialize" do
    it "doesn't raise an error" do
      expect { entity }.not_to raise_error
    end
  end

  describe "#add_observer" do
    it "adds observer" do
      expect { entity.add_observer(observer) }
        .to change { entity.observers.include?(observer) }.from(false).to(true)
    end

    context "when observer doesn't respond to update method" do
      let(:observer) { instance_double("FakeObserver") }

      it { expect { entity.add_observer(observer) }.to raise_error NoMethodError }
    end
  end

  describe "#delete_observer" do
    context "when observer is missing" do
      it "doesn't raise an error" do
        expect { entity.delete_observer(observer) }.not_to raise_error
      end
    end

    context "when observer is present" do
      it "deletes an observer" do
        entity.add_observer(observer)

        expect { entity.delete_observer(observer) }
          .to change { entity.observers.include?(observer) }.from(true).to(false)
      end
    end
  end

  describe "#notify_observers" do
    before do
      entity.add_observer(observer)
    end

    it "notifies observers with given arguments" do
      entity.notify_observers(:some, 2, { more: :arguments })

      expect(observer).to have_received(:update).with(:some, 2, { more: :arguments })
    end
  end
end
