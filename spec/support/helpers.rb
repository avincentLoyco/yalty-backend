module Yalty
  WrongAuthUser = Class.new(StandardError)

  module Helpers
    def wrap_env(envs = {})
      original_envs = ENV.to_h.slice(*envs.keys)
      envs.each { |k, v| ENV[k] = v }

      yield
    ensure
      envs.each_key { |k| ENV.delete k }
      original_envs.each { |k, v| ENV[k] = v }
    end
  end
end
