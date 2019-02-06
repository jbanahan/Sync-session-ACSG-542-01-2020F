module Api; module V1; module Admin; class BusinessValidationSchedulesController < Api::V1::Admin::AdminApiController
  def new
    cms = OpenChain::EntityCompare::TimedBusinessRuleComparator::CORE_MODULES.sort
    cms.select!{ |cm| CoreModule.find_by_class_name(cm).enabled_lambda.call }
    render json: {cm_list: cms}
  end

  def index
    scheds = BusinessValidationSchedule.all.map do |sch|
      field_label = ModelField.find_by_uid(sch.model_field_uid).label if sch.model_field_uid.present?
      date_string = "#{sch.num_days} day#{sch.num_days != 1 ? 's' : ''} #{sch.operator} #{field_label}" if sch.num_days && sch.operator && field_label
      {id: sch.id, name: sch.name, module_type: sch.module_type, date: date_string}
    end

    render json: scheds
  end

  def edit
    schedule = BusinessValidationSchedule.find params[:id]
    cm = CoreModule.find_by_class_name(schedule.module_type)
    render json: { schedule: schedule, 
                   criteria: schedule.search_criterions.map{ |sc| sc.json(current_user) }, 
                   criterion_model_fields: criterion_mf_hsh(cm, schedule),
                   schedule_model_fields: schedule_mf_hsh(cm, current_user) }
  end

  def create
    errors = []
    errors << "Name cannot be blank." if params[:schedule][:name].blank?
    errors << "Module Type cannot be blank." if params[:schedule][:module_type].blank?
    if errors.empty?
      sched = BusinessValidationSchedule.create!(module_type: params[:schedule][:module_type], name: params[:schedule][:name])
      render json: {id: sched.id}
    else
      render_error errors, 400
    end
  end

  def update
    schedule = BusinessValidationSchedule.find params[:id]
    
    errors = []
    errors << "Name cannot be blank." if params[:schedule][:name].blank?
    errors << "Date must be complete." if params[:schedule][:model_field_uid].blank? || params[:schedule][:operator].blank? || params[:schedule][:num_days].blank? 
    errors << "Schedule must include search criterions." if params[:criteria].blank?

    if errors.empty?
      params[:schedule].delete(:module_type) # ensure module_type can't be changed
      schedule.assign_attributes(params[:schedule])
      new_criterions = params[:criteria] || []
      schedule.search_criterions.delete_all
      new_criterions.each do |sc|
        schedule.search_criterions.build :model_field_uid=>sc[:mfid], :operator=>sc[:operator], :value=>sc[:value], :include_empty=>sc[:include_empty]
      end
      schedule.save!
      render json: {ok: 'ok'}
    else
      render_error errors, 400
    end
  end

  def destroy
    schedule = BusinessValidationSchedule.find params[:id]
    schedule.destroy
    render json: {ok: 'ok'}
  end

  def criterion_mf_hsh core_module, schedule
    mfs = core_module.default_module_chain.model_fields.values
    ModelField.sort_by_label(mfs).collect {|mf| {:mfid=>mf.uid,:label=>mf.label,:datatype=>mf.data_type}}
  end

  def schedule_mf_hsh core_module, user
    model_fields_list = []
    core_module.model_fields(user).each do |mfid, mf|
      model_fields_list << {'mfid' => mf.uid.to_s, 'label' => mf.label} if [:datetime, :date].include? mf.data_type
    end
    model_fields_list.sort_by{ |mf_summary| mf_summary['label'] }
  end

end; end; end; end
