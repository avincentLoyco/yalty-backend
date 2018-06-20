module Export
  module Employee
    class ChildCounter
      CHILD_ADDERS = %w(child_birth child_adoption).freeze
      CHILD_REMOVALS = %w(child_death).freeze

      def self.call(children:, attribute:, effective_at:, event_type:)
        new(
          children: children,
          attribute: attribute,
          effective_at: effective_at,
          event_type: event_type
        ).call
      end

      def initialize(children: [], attribute:, effective_at:, event_type:)
        @children     = children
        @attribute    = attribute
        @effective_at = effective_at
        @event_type   = event_type
      end

      def call
        if CHILD_REMOVALS.include?(event_type)
          children.reject! { |child| child[:value].eql?(child_data[:value]) }
        elsif CHILD_ADDERS.include?(event_type)
          children << child_data
        end
        children
      end

      private

      def child_data
        {
          value: attribute,
          effective_at: effective_at,
          event_type: event_type,
        }
      end

      attr_reader :children, :attribute, :effective_at, :event_type
    end
  end
end
