module Parrot
  module Helpers
    module_function

    def testing?
      ENV['PARROT_TESTING'] == 'true'
    end
  end
end
