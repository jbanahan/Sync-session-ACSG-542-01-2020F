require 'open_chain/email_validation_support'

module Api; module V1; class OneTimeAlertsController < Api::V1::ApiController
  include OpenChain::EmailValidationSupport

  def edit
    alert = OneTimeAlert.find params[:id]

    if alert.can_edit? current_user
      mf_digest = get_mf_digest alert
      mailing_lists = MailingList.mailing_lists_for_user(current_user).map { |ml| {id: ml.id, label: ml.name} }.unshift({id: nil, label: ""})
      render json: { alert: alert, mailing_lists: mailing_lists, criteria: alert.search_criterions.map { |sc| sc.json(current_user) }, model_fields: mf_digest }
    else
      render_forbidden
    end
  end

  def update
    # ensure these fields can't be changed
    alert_params = params[:alert]
    alert_params.delete(:module_type)
    alert_params.delete(:user_id)

    alert = OneTimeAlert.find params[:id]

    if alert.can_edit? current_user

      if alert_params[:name].blank?
        render json: {error: "You must include a name."}, status: 500
        return
      end

      emails = alert_params[:email_addresses]
      # if emails and mailing list are both empty or there is an invalid email
      if (!emails.present? && !alert_params[:mailing_list_id]) || (emails.present? && !email_list_valid?(emails))
        render json: {error: "Could not save due to missing or invalid email."}, status: 500
        return
      end

      alert_params.merge!(expire_date_last_updated_by: current_user) unless alert.expire_date == (Date.parse alert_params[:expire_date] rescue nil)
      alert.assign_attributes(alert_params)
      new_criterions = params[:criteria] || []
      alert.search_criterions.delete_all
      new_criterions.each do |sc|
        alert.search_criterions.build :model_field_uid=>sc[:mfid], :operator=>sc[:operator], :value=>sc[:value], :include_empty=>sc[:include_empty]
      end
      alert.save!
      alert.send_email(nil) if params[:send_test]
      render json: {ok: 'ok'}
    else
      render_forbidden
    end
  end

  def update_reference_fields
    if current_user.admin?
      fields = {}
      params[:fields].each do |cm_name, tuplets|
        fields[cm_name] = []
        tuplets.each { |tup| fields[cm_name] << tup["mfid"] } if tuplets
      end
      DataCrossReference.update_ota_reference_fields! fields
      render json: {ok: 'ok'}
    else
      render_forbidden
    end
  end

  def destroy
    alert = OneTimeAlert.find params[:id]

    if alert.can_edit? current_user
      alert.destroy
      render json: {ok: 'ok'}
    else
      render_forbidden
    end
  end

  private

  def get_mf_digest alert
    fields = DataCrossReference.hash_ota_reference_fields[alert.module_type]
    fields.map do |f|
      mf = ModelField.find_by_uid f
      {mfid: mf.uid, label: mf.label, datatype: mf.data_type}
    end
  end

end; end; end
