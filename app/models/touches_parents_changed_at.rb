module TouchesParentsChangedAt
  def self.included base
    base.instance_eval("after_save :touch_parent")
  end

  def touch_parents_changed_at
    cm = CoreModule.find_by_class_name self.class.to_s
    cm.touch_parents_changed_at self
  end

  private
    def touch_parent
      # Don't touch the parent if we haven't actually changed any custom_value data
      if changed?
        touch_parents_changed_at
      end
    end
end