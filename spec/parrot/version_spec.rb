require 'spec_helper'

describe 'Version' do
  it 'should have the right version string' do
    Parrot::VERSION.should == '0.0.1'
  end
end