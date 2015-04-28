class WorkflowInstance < ActiveRecord::Base
  belongs_to :base_object, polymorphic: true, inverse_of: :workflow_instances

  has_many :workflow_tasks, dependent: :destroy, inverse_of: :workflow_instance
  
  validates :base_object, presence: true
  validates :workflow_decider_class, presence: true

  def destroy_stale_tasks tasks_to_keep, types_to_destroy
    self.workflow_tasks.where('NOT workflow_tasks.id IN (?)',tasks_to_keep.compact.collect {|t| t.id}.compact).where('task_type_code IN (?)',types_to_destroy).destroy_all
  end

end
