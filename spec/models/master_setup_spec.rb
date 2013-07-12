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
      @m.custom_features_list.should == features
    end
    it 'should take a string with line breaks and return the array' do
      features = ['a','b','c']
      @m.custom_features_list = features.join('\r\n')
      @m.custom_features.should == features.join('\r\n')
      @m.custom_features_list = features
    end
    it 'should check on custom_feature?' do
      features = ['a','b','c']
      @m.custom_features_list = features
      @m.should be_custom_feature('a')
      @m.should_not be_custom_feature('d')
    end
  end

  context :current_config_version do
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

      Rails.should_receive(:root).and_return @tmp
      MasterSetup.current_config_version.should == "1.2.3"
    end
  end

  context :current_code_version do
    it "should read the current version from the config/version.txt file" do
      Rails.root.join("config", "version.txt").read.strip.should == MasterSetup.current_code_version
    end
  end

  context :need_upgrade? do
    it "should require an upgrade if the target version from the DB is not the same as the current code version" do
      MasterSetup.first.update_attributes :target_version => "UPDATE ME!!!"
      MasterSetup.need_upgrade?.should be_true
    end

    it "should not require an upgrade if the target version is same as current code version" do
      MasterSetup.first.update_attributes :target_version => MasterSetup.current_code_version
      MasterSetup.need_upgrade?.should be_false
    end

    it "should not require an upgrade if the target version is blank" do
      MasterSetup.first.update_attributes :target_version => nil
      MasterSetup.need_upgrade?.should be_false
    end
  end
end
