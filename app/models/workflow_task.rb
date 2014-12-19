class WorkflowTask < ActiveRecord::Base
  belongs_to :workflow_instance, inverse_of: :workflow_tasks
  belongs_to :group, inverse_of: :workflow_tasks

  validates :test_class_name, presence: true
  validates :name, presence: true
  validates :task_type_code, presence: true
  validates :workflow_instance, presence: true

  def test_class
    self.test_class_name.constantize
  end

  def passed?
    self.passed_at
  end

  def base_object
    return nil if self.workflow_instance.blank?
    self.workflow_instance.base_object
  end

  def payload
    JSON.parse self.payload_json
  end

  #run the test, set the passed_at value, save
  # returns true if test passed
  def test!
    passed = self.test_class.pass? self
    if passed
      if self.passed_at.blank?
        self.passed_at = 0.seconds.ago
        self.save!
      end
      return true
    else
      if self.passed_at
        self.passed_at = nil
        self.save!
      end
      return false
    end
  end
end
