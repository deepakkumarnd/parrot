require 'spec_helper'

describe Parrot do
  context 'with option -v' do
    let(:args) { %w( -v ) }

    it 'displays version info' do
      expect { Parrot::Parrot.new(args).run }.to output("Parrot #{Parrot::VERSION}\n").to_stdout
    end
  end

  # context 'with option -h' do
  #   let(:args) { %w( -h ) }

  #   it 'displays help message' do
  #     parrot = Parrot::Parrot.new(args)
  #     parrot.run
  #     # expect { parrot.run }.to output("something").to_stdout
  #   end
  # end

  context 'in quiet mode' do
    it 'will be quiet by default while testing' do
      parrot = Parrot::Parrot.new
      expect(parrot).to be_quiet
    end

    it 'will be be quiet on quiet option' do
      args = %w( -q )
      parrot = Parrot::Parrot.new(args)
      expect(parrot).to be_quiet
    end
  end

  context 'sub commands' do
    it 'has the following commands' do
      expect(Parrot::Parrot::SUB_COMMANDS).to eq(Parrot::SUB_COMMANDS_DOC.keys.map(&:to_s))
    end
  end
end