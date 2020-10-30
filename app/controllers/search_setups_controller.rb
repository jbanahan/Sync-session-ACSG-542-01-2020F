class SearchSetupsController < ApplicationController
  def show
    search_setup = SearchSetup.for_user(current_user).find(params[:id])
    respond_to do |format|
      format.json do
        render json: search_setup.to_json(methods: [:uploadable_error_messages], include: {search_columns: {only: [:model_field_uid, :rank]},
                                                                                           sort_criterions: {only: [:model_field_uid, :rank, :descending]}})
      end
    end
  end

  def update
    search_setup = SearchSetup.for_user(current_user).find(params[:id])
    if search_setup.nil?
      error_redirect "Search with ID #{params[:id]} not found."
    else
      # Modify the search criterion values for date times for lt, gt, eq, ne operators
      # adding in the user's time zone.
      append_timezone_to_datetime params

      search_setup.search_columns.destroy_all if params[:search_setup][:search_columns_attributes].present? # clear, they will be reloaded
      search_setup.sort_criterions.destroy_all # clear, they will be reloaded
      search_setup.update(permitted_params(params))
      redirect_to core_module_class(search_setup)
    end
  end

  def copy
    base = SearchSetup.for_user(current_user).find(params[:id])
    if base.nil?
      error_message = "Search with ID #{params[:id]} not found."
      respond_to do |format|
        format.html do
          error_redirect error_message
        end
        format.json do
          render json: {"error" => error_message}, status: 422
        end
      end
    else
      new_name = params[:new_name]
      new_name = "Copy of #{base.name}" if new_name.blank?
      # Make sure there's no report that already has this name..
      existing = SearchSetup.for_user(current_user).where(module_type: base.module_type, name: new_name).first
      if existing
        error_message = "A search with the name '#{new_name}' already exists.  Please use a different name or rename the existing report."
        respond_to do |format|
          format.html do
            add_flash :errors, error_message
            redirect_to core_module_class(base)
          end
          format.json do
            render json: {"error" => error_message}, status: 422
          end
        end
      else
        copy = base.deep_copy(new_name)
        copy.locked = true if base.user == User.integration
        copy.save!
        respond_to do |format|
          format.html do
            add_flash :notices, "A copy of this report has been created as '" + copy.name + "'."
            redirect_to core_module_class(copy)
          end
          format.json do
            render json: {"ok" => "ok", "id" => copy.id, "name" => copy.name}
          end
        end
      end
    end
  end

  def give
    base = SearchSetup.for_user(current_user).find_by(id: params[:id])
    raise ActionController::RoutingError, 'Not Found' unless base
    other_user = User.find(params[:other_user_id])
    error_message = nil
    if current_user.company.master? || other_user.company_id == current_user.company_id || other_user.company.master?
      base.give_to other_user
      true
    else
      error_message = "You do not have permission to give this search to user with ID #{params[:other_user_id]}."
    end
    respond_to do |format|
      format.html do
        if error_message.blank?
          add_flash :notices, "Report #{base.name} has been given to #{other_user.full_name}."
          redirect_to core_module_class(base)
        else
          error_redirect error_message
        end
      end
      format.json do
        if error_message.blank?
          render json: {"ok" => "ok", "given_to" => other_user.full_name }
        else
          render json: {"error" => error_message}, status: 422
        end
      end
    end
  end

  def destroy
    base = SearchSetup.for_user(current_user).find(params[:id])
    name = base.name
    if base.destroy
      add_flash :notices, "#{name} successfully deleted."
    else
      add_flash :errors, "#{name} could not be deleted."
    end
    redirect_to core_module_class(base)
  end

  private

  def append_timezone_to_datetime p
    p[:search_setup][:search_criterions_attributes]&.each do |_id, criterion|
      mf = ModelField.by_uid(criterion[:model_field_uid])
      if mf.data_type == :datetime && SearchCriterion.date_time_operators_requiring_timezone.include?(criterion[:operator])

        unless criterion[:value].nil? || criterion[:value].strip.length == 0
          criterion[:value] = criterion[:value] + " " + Time.zone.name
        end
      end
    end
  end

  def core_module_class search_setup
    cm = CoreModule.find_by(class_name: search_setup.module_type)
    raise "Unknown module type: #{search_setup.module_type}" if cm.nil?
    cm.klass
  end

  def permitted_params(params)
    # I am doing a permit! here for two reasons:
    # A.) Everything in the attr_accessible is on screen
    # B.) The wonkiness with nested attributes in Rails 4.2
    # TODO: Revisit this when we go to 5.x
    params.require(:search_setup).permit!
  end
end
