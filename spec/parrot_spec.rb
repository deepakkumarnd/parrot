require 'spec_helper'

describe Parrot do
  context 'with option -v' do
    let(:args) { %w[-v] }

    it 'displays version info' do
      expect { Parrot::Parrot.new(args).run }.to output("Parrot: #{Parrot::VERSION}\n").to_stdout
    end
  end

  context 'with option -h' do
    let(:args) { %w[-h] }
    it 'displays help message' do
      expect { Parrot::Parrot.new(args).run }.to output(/Sub Commands:/).to_stdout
    end
  end

  context 'without arguments' do
    it 'says no sub command was given' do
      expect { Parrot::Parrot.new([]).run }
        .to output(/\AOops! You did not provide any subcommand\.\n\n/).to_stdout
    end

    it 'displays usage instructions' do
      expect { Parrot::Parrot.new([]).run }.to output(/Sub Commands:/).to_stdout
    end
  end

  context 'with option -v and no sub command' do
    it 'does not also display usage instructions' do
      expect { Parrot::Parrot.new(%w[-v]).run }.not_to output(/Sub Commands:|Oops!/).to_stdout
    end
  end

  context 'in quiet mode' do
    it 'will be quiet by default while testing' do
      parrot = Parrot::Parrot.new
      expect(parrot).to be_quiet
    end

    it 'will be be quiet on quiet option' do
      args = %w[-q]
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
