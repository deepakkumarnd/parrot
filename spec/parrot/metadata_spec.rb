require 'spec_helper'

describe 'Metadata' do
  it 'should have the right version string' do
    expect(Parrot::VERSION).to eq '0.2.4'
  end

  it 'should have the HOMEPAGE set' do
    expect(Parrot::HOMEPAGE).not_to be_empty
  end
end