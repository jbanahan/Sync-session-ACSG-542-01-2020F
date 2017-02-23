require 'spec_helper'

describe MasterSetup do
  describe 'custom_features_list' do
    before :each do
      @m = MasterSetup.new
      @m.custom_features = nil
    end
    it 'should take an array of custom features and return the array' do
      features = ['a','b','c']
      @m.custom_features_list = features
      expect(@m.custom_features_list).to eq(features)
    end
    it 'should take a string with line breaks and return the array' do
      features = ['a','b','c']
      @m.custom_features_list = features.join('\r\n')
      expect(@m.custom_features).to eq(features.join('\r\n'))
      @m.custom_features_list = features
    end
    it 'should check on custom_feature?' do
      features = ['a','b','c']
      @m.custom_features_list = features
      expect(@m).to be_custom_feature('a')
      expect(@m).not_to be_custom_feature('d')
    end
  end

  context "current_config_version" do
    before :each do
      @tmp  = Rails.root.join("tmp")
      @config = @tmp.join("config")
      @config.mkdir unless @config.directory?
    end

    after :each do
      @config.rmtree
    end

    it "should read config version from $rails.root/config/version.txt" do
      # Swap in the temp directory for Rails.root, then place a phony config file 
      # in the relative position that master_setup is looking for it in
      @config.join("version.txt").open("w") do |f|
        f << "1.2.3\n"
      end

      expect(Rails).to receive(:root).and_return @tmp
      expect(MasterSetup.current_config_version).to eq("1.2.3")
    end
  end

  context "current_code_version" do
    it "should read the current version from the config/version.txt file" do
      expect(Rails.root.join("config", "version.txt").read.strip).to eq(MasterSetup.current_code_version)
    end
  end

  context "need_upgrade?" do
    it "should require an upgrade if the target version from the DB is not the same as the current code version" do
      MasterSetup.get.update_attributes :target_version => "UPDATE ME!!!"
      expect(MasterSetup.need_upgrade?).to be_truthy
    end

    it "should not require an upgrade if the target version is same as current code version" do
      MasterSetup.get.update_attributes :target_version => MasterSetup.current_code_version
      expect(MasterSetup.need_upgrade?).to be_falsey
    end

    it "should not require an upgrade if the target version is blank" do
      MasterSetup.get.update_attributes :target_version => nil
      expect(MasterSetup.need_upgrade?).to be_falsey
    end
  end

  describe "get_migration_lock" do
    let! (:master_setup) { MasterSetup.create! }
    subject { described_class }

    it "sets hostname into a blank migration lock" do
      expect(MasterSetup.get_migration_lock host: "host").to eq true
      expect(MasterSetup.first.migration_host).to eq "host"
    end

    it "does not set hostname if it's already set" do 
      master_setup.update_attributes! migration_host: "host2"
      expect(MasterSetup.get_migration_lock host: "host").to eq false
      expect(MasterSetup.first.migration_host).to eq "host2"
    end

    it "uses locking" do
      expect(Lock).to receive(:with_lock_retry).with(an_instance_of(MasterSetup)).and_yield
      expect(subject. get_migration_lock host: "host").to eq true
    end

    it "uses hostname syscall if host is not provided" do
      expect(subject).to receive(:hostname).with(nil).and_return 'host'

      expect(subject.get_migration_lock).to eq true
      expect(MasterSetup.first.migration_host).to eq "host"
    end
  end

  describe "release_migration_lock" do
    let! (:master_setup) { MasterSetup.create! }
    subject { described_class }

    it "clears the migration host if it's set to the current host" do
      master_setup.update_attributes! migration_host: "host"
      subject.release_migration_lock host: "host"

      master_setup.reload
      expect(master_setup.migration_host).to be_nil
    end

    it "does not clear the host if the hostname is different" do
      master_setup.update_attributes! migration_host: "host"
      subject.release_migration_lock host: "host2"

      master_setup.reload
      expect(master_setup.migration_host).to eq "host"
    end

    it "uses locking" do
      master_setup.update_attributes! migration_host: "host"
      expect(Lock).to receive(:with_lock_retry).with(an_instance_of(MasterSetup)).and_yield
      subject.release_migration_lock host: "host"
    end

    it "uses hostname syscall if host is not provided" do
      expect(subject).to receive(:hostname).with(nil).and_return 'host'

      subject.release_migration_lock
    end

    it "allows force releasing" do
      master_setup.update_attributes! migration_host: "host"
      subject.release_migration_lock host: "host2", force_release: true

      master_setup.reload
      expect(master_setup.migration_host).to be_nil
    end
  end
end
