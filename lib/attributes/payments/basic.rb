module Payments
  class Basic
    include Virtus.model

    def self.dump(data)
      data.to_hash
    end

    def self.load(data)
      new(data)
    end
  end
end
