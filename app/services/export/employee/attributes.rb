module Export
  module Employee
    class Attributes
      attr_accessor :basic, :plain, :nested, :nested_array

      def initialize
        @basic = {}
        @plain = {}
        @nested = {}
        @nested_array = []
      end
    end
  end
end
