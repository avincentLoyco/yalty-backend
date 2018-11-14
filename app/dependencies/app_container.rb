# frozen_string_literal: true

class AppContainer
  extend Dry::Container::Mixin

  import Containers::Models
  import Containers::UseCases
  import Containers::Services
  import Containers::Errors
end
