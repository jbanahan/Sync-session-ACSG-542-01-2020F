describe OpenChain::Ssm do

  subject { described_class }

  let! (:ssm_client) do
    ssm = instance_double(::Aws::SSM::Client)
    allow(subject).to receive(:ssm_client).and_return ssm
    ssm
  end

  let! (:master_setup) do
    ms = stub_master_setup
    allow(MasterSetup).to receive(:instance_directory).and_return Pathname.new("/path/to/instance")
    allow(MasterSetup).to receive(:production_env?).and_return true
    ms
  end

  let! (:instance_information) do
    allow(InstanceInformation).to receive(:deployment_group).and_return "Customer"
  end

  describe "send_clear_upgrade_errors_command" do

    it "sends comand to run clear_upgrade_errors script" do
      expect(ssm_client).to receive(:send_command).with(
        {
          document_name: "AWS-RunShellScript",
          targets: [
            {key: "tag:Application", values: ["VFI Track"]},
            {key: "tag:Group", values: ["Customer"]},
            {key: "tag:Role", values: ["Web", "Job Queue"]}
          ],
          timeout_seconds: 600,
          parameters: {
            commands: ["script/clear_upgrade_errors.sh"],
            executionTimeout: ["3600"],
            workingDirectory: ["/path/to/instance"]
          }
        }
      )
      expect(subject.send_clear_upgrade_errors_command).to eq true
    end

    it "no-ops on non-production environment" do
      expect(ssm_client).not_to receive(:send_command)
      expect(MasterSetup).to receive(:production_env?).and_return false
      expect(subject.send_clear_upgrade_errors_command).to eq true
    end
  end

  describe "send_restart_web_server_command" do
    it "sends command to run restart passenger" do
      expect(ssm_client).to receive(:send_command).with(
        {
          document_name: "AWS-RunShellScript",
          targets: [
            {key: "tag:Application", values: ["VFI Track"]},
            {key: "tag:Group", values: ["Customer"]},
            {key: "tag:Role", values: ["Web"]}
          ],
          timeout_seconds: 600,
          parameters: {
            commands: ["script/restart_application_server.sh"],
            executionTimeout: ["3600"],
            workingDirectory: ["/path/to/instance"]
          }
        }
      )
      expect(subject.send_restart_web_server_command).to eq true
    end

    it "no-ops on non-production environment" do
      expect(ssm_client).not_to receive(:send_command)
      expect(MasterSetup).to receive(:production_env?).and_return false
      expect(subject.send_clear_upgrade_errors_command).to eq true
    end
  end

  describe "send_restart_job_queue_service_command" do
    it "sends command to run restart passenger" do
      expect(ssm_client).to receive(:send_command).with(
        {
          document_name: "AWS-RunShellScript",
          targets: [
            {key: "tag:Application", values: ["VFI Track"]},
            {key: "tag:Group", values: ["Customer"]},
            {key: "tag:Role", values: ["Job Queue"]}
          ],
          timeout_seconds: 600,
          parameters: {
            commands: ["script/restart_job_queue_service.sh"],
            executionTimeout: ["3600"],
            workingDirectory: ["/path/to/instance"]
          }
        }
      )
      expect(subject.send_restart_job_queue_service_command).to eq true
    end
  end

  describe "send_restart_job_queue_command" do
    it "sends command to run restart passenger" do
      expect(ssm_client).to receive(:send_command).with(
        {
          document_name: "AWS-RunShellScript",
          targets: [
            {key: "tag:Application", values: ["VFI Track"]},
            {key: "tag:Group", values: ["Customer"]},
            {key: "tag:Role", values: ["Job Queue"]}
          ],
          timeout_seconds: 600,
          parameters: {
            commands: ['sudo -n -H -i -u ubuntu /bin/bash -l -c "cd /path/to/instance && script/restart_job_queue.sh"'],
            executionTimeout: ["3600"],
            workingDirectory: ["/path/to/instance"]
          }
        }
      )
      expect(subject.send_restart_job_queue_command).to eq true
    end

    it "no-ops on non-production environment" do
      expect(ssm_client).not_to receive(:send_command)
      expect(MasterSetup).to receive(:production_env?).and_return false
      expect(subject.send_clear_upgrade_errors_command).to eq true
    end
  end
end