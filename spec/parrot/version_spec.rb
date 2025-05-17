require 'spec_helper'

describe 'Version' do
  it 'should have the right version string' do
    expect(Parrot::VERSION).to eq '0.1.0'
  end
end