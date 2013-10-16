require 'spec_helper'

describe Parrot::Builder do

  context 'Builder Class' do
    it 'should create a NewCommand object' do
      Parrot::Builder.new('new')
    end

    it 'should create a BuildCommand object' do
      Parrot::Builder.new('build')
    end

    it 'should create a NewCommand object' do
      Parrot::Builder.new('watch')
    end

    it 'should raise error if the command is invalid' do
      expect { Parrot::Builder.new('foo') }.to raise_error(NameError)
    end
  end
end