module OpenChain; module WorkflowTester; class AttachmentTypeWorkflowTest
  def self.category; 'Attachments'; end
  def self.pass? workflow_task
    type = workflow_task.payload['attachment_type']
    return false if type.blank?
    workflow_task.base_object.attachments.find_by_attachment_type type
  end
end; end; end;