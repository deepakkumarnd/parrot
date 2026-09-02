require 'spec_helper'

describe 'Version' do
  it 'should have the right version string' do
    expect(Parrot::VERSION).to eq '0.2.4'
  end
end