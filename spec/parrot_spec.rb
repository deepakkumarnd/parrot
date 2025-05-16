require 'spec_helper'

describe Parrot do
  context 'Option -v' do
    let(:args) { %w( -v ) }

    it 'displays version info' do
      Parrot::Parrot.new(args)
    end
  end

  context 'Option -h' do
    let(:args) { %w( -h ) }

    it 'displays help message' do
      Parrot::Parrot.new(args)
    end
  end

  context 'quiet mode' do
    let(:parrot) { Parrot::Parrot.new }

    it 'will not be quiet by default' do
      parrot = Parrot::Parrot.new
      parrot.should_not be_quiet
    end

    it 'will be be quiet on quiet option' do
      args = %w( -q )
      parrot = Parrot::Parrot.new(args)
      parrot.should be_quiet
    end
  end

  context 'sub commands' do
    it 'has the following commands' do
      Parrot::Parrot::SUB_COMMANDS.should == %w( new build watch )
    end
  end
end