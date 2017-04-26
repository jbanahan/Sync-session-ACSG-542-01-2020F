require 'spec_helper'

describe OpenChain::PasswordValidationRegistry do
  before do
    described_class.clear
  end

  describe '#register' do
    it 'should register if class implements valid_password?' do
      c = Class.new do
        def self.valid_password? user, password
        end
      end

      described_class.register c
      expect(described_class.registered.to_a).to eq [c]
    end

    it 'should fail if the class doesn\'t implement valid_password?' do
      c = Class.new do
      end

      expect { described_class.register c}.to raise_error(/password/)
      expect(described_class.registered.to_a).to be_empty
    end
  end

  describe 'specific registry getters' do
    before do
      @ca = Class.new do
        def self.valid_password? user, password
      end
      end
      described_class.register @ca
    end

    it 'should return registered classes that respond to valid_password?' do
      expect(described_class.registered_for_valid_password).to eq [@ca]
    end
  end
end