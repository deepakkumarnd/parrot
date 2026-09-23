module Parrot
  module Helpers
    extend self

    def testing?
      ENV['PARROT_TESTING'] == 'true'
    end
  end
end