module TouchesParentsChangedAt
  def self.included base
    base.instance_eval("after_save :touch_parents_changed_at")
  end

  def touch_parents_changed_at
    cm = CoreModule.find_by_class_name self.class.to_s
    cm.touch_parents_changed_at self
  end
end
