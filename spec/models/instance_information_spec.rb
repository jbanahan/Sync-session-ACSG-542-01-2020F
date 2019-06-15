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
end 
