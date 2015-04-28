module OpenChain; module WorkflowTester; class ModelFieldWorkflowTest
  def self.category; 'Data'; end
  def self.pass? workflow_task
    bo = workflow_task.object_to_test
    payload = workflow_task.payload
    regex_hash = {}
    payload['model_fields'].each do |m|
      regex_hash[ModelField.find_by_uid(m['uid'])] = m['regex']
    end
    regex_hash.each do |mf,reg_str|
      val = mf.process_export(bo,nil,true)
      return false if val.blank?
      if !reg_str.blank?
        return false unless val.match(reg_str)
      end
    end
    return true
  end
end; end; end