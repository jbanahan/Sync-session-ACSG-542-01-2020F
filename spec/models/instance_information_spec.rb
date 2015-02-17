require 'spec_helper'

describe InstanceInformation do

  around :each do |ex|
    Tempfile.open("InstanceInformationTmp") do |f|
      @tf = f
      ex.run
    end
  end

  describe "server_role" do
    it 'uses aws tag fs to identify server role' do
      @tf << "Server Role"
      @tf.flush
      InstanceInformation.should_receive(:tag_path).with("Role").and_return @tf.path
      expect(InstanceInformation.server_role).to eq "Server Role"
    end
  end

  describe "server_name" do
    it 'uses aws tag fs to identify server name' do
      @tf << "Server Name"
      @tf.flush
      InstanceInformation.should_receive(:tag_path).with("Name").and_return @tf.path
      expect(InstanceInformation.server_name).to eq "Server Name"
    end
  end

  describe "webserver?" do
    it "identifies as webserver if role tag is Web" do
      @tf << "Web"
      @tf.flush

      InstanceInformation.should_receive(:tag_path).with("Role").and_return @tf.path
      expect(InstanceInformation.webserver?).to be_true
    end

    it "returns false if role is not Web" do
      @tf << "Not Web"
      @tf.flush

      InstanceInformation.should_receive(:tag_path).with("Role").and_return @tf.path
      expect(InstanceInformation.webserver?).to be_false
    end
  end

  describe "job_queue?" do
    it "identifies as job queue if role tag is Job Queue" do
      @tf << "Job Queue"
      @tf.flush

      InstanceInformation.should_receive(:tag_path).with("Role").and_return @tf.path
      expect(InstanceInformation.job_queue?).to be_true
    end

    it "returns false if role is not Job Queue" do
      @tf << "Not Job Queue"
      @tf.flush

      InstanceInformation.should_receive(:tag_path).with("Role").and_return @tf.path
      expect(InstanceInformation.job_queue?).to be_false
    end
  end


  describe "tag_base_dir" do
    it "uses the correct base dir" do
      expect(InstanceInformation.tag_base_dir).to eq "/etc/aws-fs/tags"
    end
  end

    
end 