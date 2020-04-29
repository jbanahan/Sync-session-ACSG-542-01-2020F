describe InstanceInformation do

  def clear_vars
    # Clear the caching information
    InstanceInformation.class_variable_set(:@@server_role, nil)
    InstanceInformation.class_variable_set(:@@server_name, nil)
    InstanceInformation.class_variable_set(:@@deployment_group, nil)
  end

  before(:each) { clear_vars }
  after(:each) { clear_vars }

  describe "server_role" do
    it 'uses aws tag fs to identify server role' do
      expect(InstanceInformation).to receive(:read_file).with("/etc/aws-fs/tags/Role").and_return "Server Role"
      expect(InstanceInformation.server_role).to eq "Server Role"
      # Do this again to ensure that the file's not read again
      expect(InstanceInformation.server_role).to eq "Server Role"
    end
  end

  describe "server_name" do
    it 'uses aws tag fs to identify server name' do
      expect(InstanceInformation).to receive(:read_file).with("/etc/aws-fs/tags/Name").and_return "Server Name"
      expect(InstanceInformation.server_name).to eq "Server Name"
      # Do this again to ensure that the file's not read again
      expect(InstanceInformation.server_name).to eq "Server Name"
    end
  end

  describe "deployment_group" do
    it 'uses aws tag fs to identify server group' do
      expect(InstanceInformation).to receive(:read_file).with("/etc/aws-fs/tags/Group").and_return "Server Group"
      expect(InstanceInformation.deployment_group).to eq "Server Group"
      # Do this again to ensure that the file's not read again
      expect(InstanceInformation.deployment_group).to eq "Server Group"
    end
  end

  describe "webserver?" do
    it "identifies as webserver if role tag is Web" do
      expect(InstanceInformation).to receive(:read_file).with("/etc/aws-fs/tags/Role").and_return "Web"
      expect(InstanceInformation.webserver?).to eq true
    end

    it "returns false if role is not Web" do
      expect(InstanceInformation).to receive(:read_file).with("/etc/aws-fs/tags/Role").and_return "Not Web"
      expect(InstanceInformation.webserver?).to eq false
    end
  end

  describe "job_queue?" do
    it "identifies as job queue if role tag is Job Queue" do
      expect(InstanceInformation).to receive(:read_file).with("/etc/aws-fs/tags/Role").and_return "Job Queue"
      expect(InstanceInformation.job_queue?).to eq true
    end

    it "returns false if role is not Job Queue" do
      expect(InstanceInformation).to receive(:read_file).with("/etc/aws-fs/tags/Role").and_return "Not Job Queue"
      expect(InstanceInformation.job_queue?).to eq false
    end
  end

  describe "tag_base_dir" do
    it "uses the correct base dir" do
      expect(InstanceInformation.tag_base_dir).to eq "/etc/aws-fs/tags"
    end
  end

  describe "check_in" do
    subject { described_class }
    let (:now) { Time.zone.now }

    before :each do
      allow(subject).to receive(:server_name).and_return "Name"
      allow(subject).to receive(:server_role).and_return "Role"
      allow(MasterSetup).to receive(:current_code_version).and_return "Version"
    end

    it "creates a new InstanceInformation to check in" do
      i = nil
      Timecop.freeze(now) { i = subject.check_in "dev.development.net" }
      expect(i.last_check_in).to eq now
      expect(i.version).to eq "Version"
      expect(i.name).to eq "Name"
      expect(i.role).to eq "Role"
    end

    it "updates an existing InstanceInformation" do
      i = InstanceInformation.create! host: "dev.development.net"
      Timecop.freeze(now) { subject.check_in "dev.development.net" }
      i.reload
      expect(i.last_check_in.to_i).to eq now.to_i
      expect(i.version).to eq "Version"
      expect(i.name).to eq "Name"
      expect(i.role).to eq "Role"
    end

    it "uses rails config hostname if given hostname is blank" do
      expect(MasterSetup).to receive(:rails_config_key).with(:hostname).and_return "www.development.net"
      i = subject.check_in
      expect(i.host).to eq "www.development.net"
    end
  end
end
