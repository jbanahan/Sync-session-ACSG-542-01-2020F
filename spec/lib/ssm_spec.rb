describe OpenChain::Ssm do

  subject { described_class }

  let! (:ssm_client) do 
    ssm = instance_double(::Aws::SSM::Client)
    allow(subject).to receive(:ssm_client).and_return ssm
    ssm
  end

  describe "send_clear_upgrade_errors_command" do 

    it "sends comand to run clear_upgrade_errors script" do
      allow(InstanceInformation).to receive(:deployment_group).and_return "Customer"
      expect(MasterSetup).to receive(:instance_directory).and_return Pathname.new("/path/to/instance")
      expect(ssm_client).to receive(:send_command).with(
        {
          document_name: "AWS-RunShellScript",
          targets: [
            {key: "tag:Application", values: ["VFI Track"]},
            {key: "tag:Role", values: ["Web", "Job Queue"]},
            {key: "tag:Group", values: ["Customer"]}
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

    it "sends command to run script using given parameters" do
      expect(MasterSetup).not_to receive(:instance_directory)

      expect(ssm_client).to receive(:send_command).with(
        {
          document_name: "AWS-RunShellScript",
          targets: [
            {key: "tag:TagName", values: ["TagValue"]},
            {key: "tag:TagName2", values: ["Value1", "Value2"]}
          ],
          timeout_seconds: 600,
          parameters: {
            commands: ["script/clear_upgrade_errors.sh"],
            executionTimeout: ["3600"],
            workingDirectory: ["/some/alternate/path"]
          }
        }
      )

      expect(subject.send_clear_upgrade_errors_command working_directory: "/some/alternate/path", instance_targets: {"TagName"=>"TagValue", "TagName2" => ["Value1", "Value2"]}).to eq true
    end
  end
end