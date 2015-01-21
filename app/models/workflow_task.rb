require 'open_chain/workflow_tester/attachment_type_workflow_test'
require 'open_chain/workflow_tester/multi_state_workflow_test'
require 'open_chain/workflow_tester/model_field_workflow_test'

class WorkflowTask < ActiveRecord::Base
  DUE_AT_LABELS = ["Complete","No Due Date","Overdue","Upcoming","Later"]
  DUE_AT_DESCRIPTIONS = {
    'Complete'=>"complete",
    'No Due Date'=>"don't have a due date",
    'Overdue'=>"already overdue",
    'Upcoming'=>"due in the next 3 days",
    'Later'=>"due more than three days from now"
  }
  belongs_to :workflow_instance, inverse_of: :workflow_tasks, touch: true
  belongs_to :group, inverse_of: :workflow_tasks
  has_one :multi_state_workflow_task, inverse_of: :workflow_task, dependent: :destroy

  validates :test_class_name, presence: true
  validates :name, presence: true
  validates :task_type_code, presence: true
  validates :workflow_instance, presence: true

  scope :for_user, lambda {|u| where('workflow_tasks.group_id IN (SELECT group_id FROM user_group_memberships WHERE user_id = ?)',u.id)}

  scope :not_passed, where('workflow_tasks.passed_at is null')

  scope :for_base_object, lambda {|o| joins(:workflow_instance).where("workflow_instances.base_object_type = :obj_type AND workflow_instances.base_object_id = :obj_id",{obj_type:o.class.name,obj_id:o.id})}

  #named this are_overdue to avoid confusion with object level "overdue?" method
  scope :are_overdue, where('workflow_tasks.due_at < now()')

  def overdue?
    return false unless self.due_at && ! self.passed?
    return self.due_at < 0.seconds.ago
  end

  def due_at_label
    return "Complete" if self.passed?
    return "No Due Date" if self.due_at.nil?
    return "Overdue" if self.overdue?
    return "Upcoming" if self.due_at < 3.days.from_now
    return "Later"
  end

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

  def can_edit? user
    return false if self.group.nil?
    return false unless user.in_group?(self.group)
    return false unless self.workflow_instance.base_object.can_view?(user)
    return true
  end
end
