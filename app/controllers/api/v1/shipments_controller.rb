require 'open_chain/custom_handler/isf_xml_generator'
require 'open_chain/registries/order_booking_registry'
require 'open_chain/api/v1/shipment_api_json_generator'

module Api; module V1; class ShipmentsController < Api::V1::ApiCoreModuleControllerBase
  include ActionView::Helpers::NumberHelper

  def core_module
    CoreModule::SHIPMENT
  end

  def create_booking_from_order
    lines, order = make_booking_lines_for_order(params[:order_id])
    h = {
      shp_ref: Shipment.generate_reference,
      shp_imp_id: order.importer_id,
      shp_ven_id: order.vendor_id,
      booking_lines: lines
    }
    OpenChain::Registries::OrderBookingRegistry.book_from_order_hook(h, order, lines)
    params['shipment'] = h.with_indifferent_access
    do_create core_module
  end

  def book_order
    lines, order = make_booking_lines_for_order(params[:order_id])
    s = Shipment.find params[:id]
    raise StatusableError.new('Order and shipment importer must match.', 400) unless s.importer == order.importer
    raise StatusableError.new('Order and shipment vendor must match.', 400) unless s.vendor == order.vendor
    # rubocop:disable Lint/AssignmentInCondition
    # Yes, this is broken. It has been broken since Glick wrote it. However, we do not want to mess with the line in case
    # it manages to bork code (specifically Lumber code.)
    raise StatusableError.new('Order and shipment must have same ship from address.', 400) unless s.ship_from = order.ship_from
    # rubocop:enable Lint/AssignmentInCondition
    h = {
      id: s.id,
      booking_lines: lines
    }
    OpenChain::Registries::OrderBookingRegistry.book_from_order_hook(h, order, lines)
    params['shipment'] = h.with_indifferent_access
    do_update core_module
  end

  def available_orders
    s = shipment
    ord_fields = [:ord_ord_num, :ord_cust_ord_no, :ord_mode, :ord_imp_name, :ord_ord_date, :ord_ven_name]
    r = []
    s.available_orders(current_user).order('customer_order_number').limit(25).each do |ord|
      hsh = {id: ord.id}
      ord_fields.each {|uid| hsh[uid] = output_generator.export_field(uid, ord)}
      r << hsh
    end
    render json: {available_orders: r}
  end

  def booked_orders
    s = shipment
    ord_fields = [:ord_ord_num, :ord_cust_ord_no]
    result = []
    lines_available = s.booking_lines.where('order_line_id IS NOT NULL').any?
    order_ids = s.booking_lines.where('order_id IS NOT NULL').uniq.pluck(:order_id) # select distinct order_id from booking_lines where...
    Order.where(id: order_ids).each do |order|
      hsh = {id: order.id}
      ord_fields.each {|uid| hsh[uid] = output_generator.export_field(uid, order)}
      result << hsh
    end
    render json: {booked_orders: result, lines_available: lines_available}
  end

  # makes a fake order based on booking lines.
  def available_lines
    s = shipment
    lines = s.booking_lines.where('order_line_id IS NOT NULL').map do |line|
      {id: line.order_line_id,
       ordln_line_number: line.line_number,
       ordln_puid: line.product_identifier,
       ordln_sku: line.order_line.sku,
       ordln_ordered_qty: line.quantity,
       linked_line_number: line.order_line.line_number,
       linked_cust_ord_no: line.customer_order_number}
    end
    render json: {lines: lines}
  end

  def open_bookings
    # If we're looking for bookings for a specific order then the order_id should be sent, otherwise, if it's not we'll limit the bookings
    # based on the user's linked companies.
    order = params["order_id"].present? ? Order.where(id: params["order_id"].to_i).first : nil

    shipments = Shipment.search_secure current_user, Shipment.all
    if order
      if order.can_view?(current_user)
        shipments = shipments.where(vendor_id: order.vendor_id, importer_id: order.importer_id)
      else
        shipments = shipments.where("1 = 0")
      end
    elsif current_user.company.vendor?
      shipments = shipments.where(vendor_id: current_user.company_id)
    elsif current_user.company.importer?
      shipments = shipments.where(importer_id: current_user.company_id)
    else
      shipments = shipments.where(importer_id: current_user.company.linked_companies.where(importer: true).pluck(:id))
    end

    shipments = OpenChain::Registries::OrderBookingRegistry.open_bookings_hook(current_user, shipments, order)
    results = shipments.order("updated_at DESC").limit(200).map do |s|
      ship_hash = obj_to_json_hash(s)

      # We're going to add one special permission for this request that indicates if the order requested can be booked to the shipment
      if order
        ship_hash['permissions'][:can_book_order_to_shipment] = OpenChain::Registries::OrderBookingRegistry.can_book_order_to_shipment?(order, s)
      end
      ship_hash
    end

    render json: {results: results}
  end

  def process_tradecard_pack_manifest
    attachment_job('Tradecard Pack Manifest')
  end

  def process_booking_worksheet
    attachment_job('Booking Worksheet')
  end

  def process_manifest_worksheet
    attachment_job('Manifest Worksheet')
  end

  def request_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to request a booking.", :forbidden) unless s.can_request_booking?(current_user)
    s.async_request_booking! current_user
    render json: {'ok' => 'ok'}
  end

  def approve_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to approve a booking.", :forbidden) unless s.can_approve_booking?(current_user)
    s.async_approve_booking! current_user
    render json: {'ok' => 'ok'}
  end

  def confirm_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to confirm a booking.", :forbidden) unless s.can_confirm_booking?(current_user)
    s.async_confirm_booking! current_user
    render json: {'ok' => 'ok'}
  end

  def revise_booking
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to revise this booking.", :forbidden) unless s.can_revise_booking?(current_user)
    s.async_revise_booking! current_user
    render json: {'ok' => 'ok'}
  end

  def request_cancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to request a booking.", :forbidden) unless s.can_request_cancel?(current_user)
    s.async_request_cancel! current_user
    render json: {'ok' => 'ok'}
  end

  def cancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to cancel this booking.", :forbidden) unless s.can_cancel?(current_user)
    s.async_cancel_shipment! current_user
    render json: {'ok' => 'ok'}
  end

  def uncancel
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have permission to undo canceling this booking.", :forbidden) unless s.can_uncancel?(current_user)
    s.async_uncancel_shipment! current_user
    render json: {'ok' => 'ok'}
  end

  def send_shipment_instructions
    s = Shipment.find params[:id]
    raise StatusableError.new("You do not have to send shipment instructions.", :forbidden) unless s.can_send_shipment_instructions?(current_user)
    s.async_send_shipment_instructions! current_user
    render json: {'ok' => 'ok'}
  end

  def send_isf
    shipment = Shipment.find params[:id]
    if shipment.valid_isf?
      ISFXMLGenerator.delay.generate_and_send(shipment.id, !shipment.isf_sent_at)
      shipment.mark_isf_sent!(current_user)
    else
      raise 'Invalid ISF! <ul><li>' + shipment.errors.full_messages.join('</li><li>') + '</li></ul>'
    end
  end

  def save_object h
    shp = if h['id'].blank?
            Shipment.new
          else
            Shipment.includes([
                                {shipment_lines: [:piece_sets, {custom_values: [:custom_definition]}, :product]},
                                {booking_lines: [:order_line, :product]},
                                :containers,
                                {custom_values:  [:custom_definition]}])
                    .find_by(id: h['id'])
          end
    raise StatusableError.new("Object with id #{h['id']} not found.", 404) if shp.nil?
    shp = freeze_custom_values shp, false # don't include order fields
    import_fields h, shp, CoreModule::SHIPMENT
    load_containers shp, h
    load_carton_sets shp, h
    load_lines shp, h
    load_booking_lines shp, h
    raise StatusableError.new("You do not have permission to save this Shipment.", :forbidden) unless shp.can_edit?(current_user)
    shp.save if shp.errors.full_messages.blank?
    shp
  end

  def json_generator
    OpenChain::Api::V1::ShipmentApiJsonGenerator.new
  end

  def shipment_lines
    s = shipment
    h = {id: s.id}
    render_order_fields = output_generator.render_order_fields?
    h['lines'] = output_generator
                 .render_lines(output_generator.preload_shipment_lines(s, render_order_fields, true),
                               output_generator.shipment_line_fields_to_render, render_order_fields)

    render json: {'shipment' => h}
  end

  def booking_lines
    s = shipment
    h = {id: s.id}
    h['booking_lines'] = output_generator.render_lines(output_generator.preload_booking_lines(s), output_generator.booking_line_fields_to_render)

    render json: {'shipment' => h}
  end

  # override api_controller method to pre-load lines
  def find_object_by_id id
    includes_array = [
      {shipment_lines: [:piece_sets, :custom_values, :product]},
      :containers,
      :custom_values
    ]
    render_order_fields = output_generator.render_order_fields?

    includes_array[0][:shipment_lines][0] = {piece_sets: {order_line: [:custom_values, :product, :order]}} if render_order_fields
    s = Shipment.where(id: id).includes(includes_array).first
    s = freeze_custom_values s, render_order_fields
    s
  end

  def autocomplete_order
    results = []
    if params[:n].present?
      s = shipment

      orders = s.available_orders current_user
      results = orders.where('customer_order_number LIKE ? OR order_number LIKE ?', "%#{params[:n]}%", "%#{params[:n]}%")
                      .limit(10)
                      .collect do |order|
                    # Use whatever field matched as the title that's getting returned
                    title = (order.customer_order_number.to_s.upcase.include?(params[:n].to_s.upcase) ? order.customer_order_number : order.order_number)
                    {order_number: title, id: order.id}
      end
    end

    render json: results
  end

  def autocomplete_product
    results = []
    if params[:n].present?
      s = shipment

      products = s.available_products current_user
      results = products.where("unique_identifier LIKE ? ", "%#{params[:n]}%")
                        .limit(10)
                        .collect {|product| { unique_identifier: product.unique_identifier, id: product.id }}
    end

    render json: results
  end

  def autocomplete_address
    json = []
    if params[:n].present?
      s = shipment

      result = Address.where('addresses.name like ?', "%#{params[:n]}%")
                      .where(in_address_book: true)
                      .joins(:company).where(Company.secure_search(current_user))
                      .where(companies: {id: s.importer_id})

      result = result.order(:name)
      result = result.limit(10)
      json = result.map {|address| {name: address.name, full_address: address.full_address, id: address.id} }
    end

    render json: json
  end

  def create_address
    s = shipment

    address = Address.new params[:address]
    address.company = s.importer

    address.save!

    render json: address
  end

  private

  def shipment
    s = Shipment.find params[:id]
    raise StatusableError.new("Shipment not found.", 404) unless s.can_view?(current_user)
    s
  end

  def load_lines shipment, h
# If the product id is set, then there's no need for these fields (and they'll slow down loading)
# If both of these are present, remove the shpln_prod_db_id because it doesn't validate user can view the product
# dont' need to update for both
h['lines']&.each_with_index do |base_ln, _i|
        ln = base_ln.clone
        # If the product id is set, then there's no need for these fields (and they'll slow down loading)
        if ln["shpln_prod_id"].present? || ln["shpln_prod_db_id"].present?
          ln.delete 'shpln_puid'
          ln.delete 'shpln_pname'
          if ln["shpln_prod_db_id"].present? && ln["shpln_prod_id"].present?
            # If both of these are present, remove the shpln_prod_db_id because it doesn't validate user can view the product
            ln.delete 'shpln_prod_db_id'
          end
        elsif ln['shpln_puid'].present? && ln['shpln_pname'].present?
          ln.delete 'shpln_pname' # dont' need to update for both
        end
        s_line = shipment.shipment_lines.find {|obj| match_numbers?(ln['id'], obj.id) || match_numbers?(ln['shpln_line_number'], obj.line_number)}
        if s_line.nil?
          raise StatusableError.new("You cannot add lines to this shipment.", 400) unless shipment.can_add_remove_shipment_lines?(current_user)
          s_line = shipment.shipment_lines.build(line_number: ln['cil_line_number'])
        end
        if ln['_destroy']
          raise StatusableError.new("You cannot remove lines from this shipment.", 400) unless shipment.can_add_remove_shipment_lines?(current_user)
          s_line.mark_for_destruction
          next
        end
        import_fields ln, s_line, CoreModule::SHIPMENT_LINE
        if ln['linked_order_line_id']
          o_line = OrderLine.find_by id: ln['linked_order_line_id']
          shipment.errors[:base] << "Order line #{ln['linked_order_line_id']} not found." unless o_line&.can_view?(current_user)
          s_line.product = o_line.product if s_line.product.nil?
          # rubocop:disable Layout/LineLength
          shipment.errors[:base] << "Order line #{o_line.id} does not have the same product as the shipment line provided (#{s_line.product.unique_identifier})" unless s_line.product == o_line.product
          # rubocop:enable Layout/LineLength
          s_line.linked_order_line_id = ln['linked_order_line_id']
        end
        shipment.errors[:base] << "Product required for shipment lines." unless s_line.product
        shipment.errors[:base] << "Product not found." if s_line.product && !s_line.product.can_view?(current_user)
end
  end

  def load_booking_lines(shipment, h)
    if h['booking_lines']
      # line deletes won't have order ids, so we can skip them
      order_line_ids = h['booking_lines'].map {|bl| bl["_destroy"].to_s.to_boolean ? nil : bl['bkln_order_line_id'].to_i}.uniq.compact
      raise StatusableError.new("Order has different importer from shipment", 400) unless match_importer?(shipment, order_line_ids)

      h['booking_lines'].each_with_index do |base_ln, i|
        ln = base_ln.clone
        s_line = shipment.booking_lines.find {|obj| match_numbers?(ln['id'], obj.id) || match_numbers?(ln['bkln_line_number'], obj.line_number)}
        if s_line.nil?
          raise StatusableError.new("You cannot add lines to this shipment.", 400) unless shipment.can_add_remove_booking_lines?(current_user)
          max_line_number = shipment.booking_lines.maximum(:line_number) || 0
          s_line = shipment.booking_lines.build(line_number: max_line_number + (i + 1))
        end
        if ln['_destroy']
          raise StatusableError.new("You cannot remove lines from this shipment.", 400) unless shipment.can_add_remove_booking_lines?(current_user)
          s_line.mark_for_destruction
          next
        end
        s_line.order_line_id = ln['bkln_order_line_id'] if ln['bkln_order_line_id']
        # If the data has a order line id, blank out the order id and product id values.  The order line should always provide order and product data for the booking line.
        # If order line id is set and order or product ids are present a validation will also fail and the save will rollback.
        if s_line.order_line_id.present?
          s_line.order_id = nil
          s_line.product_id = nil
          ln['bkln_order_id'] = nil
          ln['bkln_product_id'] = nil
        end
        import_fields ln, s_line, CoreModule::BOOKING_LINE
      end
    end
  end

  def match_importer? shipment, order_line_ids
    # If we don't have any ids, then there's no conflict between the header and the lines
    return true if order_line_ids.length == 0

    qry = <<-SQL
      SELECT DISTINCT imp.id
      FROM companies imp
        INNER JOIN orders o ON o.importer_id = imp.id
        INNER JOIN order_lines ol ON ol.order_id = o.id
      WHERE ol.id IN (?)
    SQL
    order_importer_ids = ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_array([qry, order_line_ids])).to_a.flatten
    order_importer_ids == Array.wrap(shipment.importer_id)
  end

  def load_containers shipment, h
    update_collection('containers', shipment, h, CoreModule::CONTAINER)
  end

  def load_carton_sets shipment, h
    update_collection('carton_sets', shipment, h, CoreModule::CARTON_SET)
  end

  def update_collection(collection_name, shipment, h, core_module)
    if h[collection_name]
      collection = h[collection_name]
      collection.each do |ln|
        cs = shipment.send(collection_name).find { |obj| match_numbers? ln['id'], obj.id }
        cs = shipment.send(collection_name).build if cs.nil?
        if ln['_destroy']
          if all_shipment_lines_will_be_deleted?(cs.shipment_lines, h['lines'])
            cs.mark_for_destruction
            next
          else
            shipment.errors[:base] << "Cannot delete #{collection_name} linked to shipment lines."
          end
        end
        import_fields ln, cs, core_module
      end
    end
  end

  def all_shipment_lines_will_be_deleted? line_collection, line_array
    line_collection.each do |ln|
      l_a = line_array || []
      ln_hash = l_a.find {|lh| lh['id'].to_s == ln.id.to_s}

      # if the hash has the _destroy then keep going to the next line
      next if ln_hash && ln_hash['_destroy']

      # didn't find a _destroy for this line, so fail
      return false
    end
  end

  def match_numbers? hash_val, number
    hash_val.present? && hash_val.to_s == number.to_s
  end

  def freeze_custom_values s, include_order_lines
    # force the internal cache of custom values for so the
    # get_custom_value methods don't double check the DB for missing custom values
    if s
      s.freeze_custom_values
      s.shipment_lines.each do |sl|
        sl.freeze_custom_values
        sl.product&.freeze_custom_values

        if include_order_lines
          sl.piece_sets.each do |ps|
            ol = ps.order_line
            if ol
              ol.freeze_custom_values
              ol.product&.freeze_custom_values
            end
          end
        end
      end
    end
    s
  end

  def attachment_job(job_name)
      s = Shipment.find params[:id]
      raise StatusableError.new("You do not have permission to edit this Shipment.", :forbidden) unless s.can_edit?(current_user)
      ids_to_process = params[:attachment_ids].map(&:to_i)
      check_for_unlinked_attachments(s.attachments, ids_to_process)
      ajs = get_attachment_process_jobs(s, ids_to_process, job_name)

      if ajs.count > 1
        AttachmentProcessJobRunner.delay.async_run_jobs(current_user.id, ajs.map(&:id), job_name, params[:manufacturer_address_id], params[:enable_warnings])
        render json: {object_param_name => obj_to_json_hash(s), notices: ["Worksheets have been submitted for processing. You'll receive a system message when they finish."]}
      else
        AttachmentProcessJobRunner.run_job(ajs.first, job_name, params[:manufacturer_address_id], params[:enable_warnings])
        render_show CoreModule::SHIPMENT
      end
  rescue StandardError => e
      ajs.first.update!(error_message: e.message) if ajs&.first && !(e.instance_of? AttachmentAlreadyProcessedError)
      raise e
  end

  class AttachmentProcessJobRunner
    def self.run_job aj, job_name, manufacturer_address_id, enable_warnings
      aj.update!(start_at: Time.zone.now, error_message: nil)
      if ['Tradecard Pack Manifest', 'Manifest Worksheet'].include? job_name
        aj.process manufacturer_address_id: manufacturer_address_id, enable_warnings: enable_warnings
      else
        aj.process enable_warnings: enable_warnings
      end
    end

    def self.async_run_jobs user_id, ids, job_name, manufacturer_address_id, enable_warnings
      errors = []
      aj = nil
      ids.each do |id|

          aj = AttachmentProcessJob.find id
          run_job aj, job_name, manufacturer_address_id, enable_warnings
      rescue StandardError => e
          errors << "#{aj.attachment.attached_file_name}: #{e.message}"
          aj.update!(error_message: e.message) if !(e.instance_of? AttachmentAlreadyProcessedError)

      end

      user = User.find user_id
      if errors.present?
        # rubocop:disable Rails/OutputSafety
        user.messages.create! subject: "Shipment #{aj.attachable.reference} worksheet upload completed with errors.",
                              body: "The following worksheets could not be processed *** #{errors.join(' *** ')}".html_safe
        # rubocop:enable Rails/OutputSafety
      else
        user.messages.create! subject: "Shipment #{aj.attachable.reference} worksheet upload completed.",
                              body: "All worksheets processed successfully."
      end
    end
  end

  class AttachmentAlreadyProcessedError < StatusableError
    def initialize att_names
      super "Processing cancelled. The following attachments have already been submitted: #{att_names.join(', ')}", 400
    end
  end

  def check_for_unlinked_attachments atts, ids_to_process
    ids = atts.map(&:id)
    return if ids.blank?

    unlinked_at_names = Attachment.where(id: ids_to_process)
                                  .where("id NOT IN (?)", ids)
                                  .map(&:attached_file_name)

    if unlinked_at_names.present?
      raise StatusableError.new("Processing cancelled. The following attachments are not linked to the shipment: #{unlinked_at_names.join(', ')}", 400)
    end
  end

  def get_attachment_process_jobs shipment, ids_to_process, job_name
    existing_ajs = shipment.attachment_process_jobs.where(attachment_id: ids_to_process, job_name: job_name)
    already_submitted_names = existing_ajs.select { |aj| aj.start_at && aj.error_message.blank? }.map { |aj| aj.attachment.attached_file_name}
    raise AttachmentAlreadyProcessedError, already_submitted_names if already_submitted_names.present?
    ids_to_process.map do |id|
      existing_ajs.find do |aj|
        aj.attachment_id == id
        # set start_at even though it will eventually be overwritten. Prevents user from submitting attachments more than once when processing is done on a delay
      end || AttachmentProcessJob.create!(attachable: shipment, user: current_user, attachment_id: id, job_name: job_name,
                                          start_at: Time.zone.now, error_message: nil)
    end
  end

  def make_booking_lines_for_order order_id
    o = Order.includes(:order_lines).where(id: order_id).first
    raise StatusableError.new("Order not found", 404) unless o.can_view?(current_user)
    raise StatusableError.new("You do not have permission to book this order.", 403) unless o.can_book?(current_user)
    lines = []
    o.order_lines.each do |ol|
      bl = HashWithIndifferentAccess.new
      bl[:bkln_order_line_id] = ol.id
      bl[:bkln_quantity] = ol.quantity
      bl[:bkln_var_db_id] = ol.variant_id
      lines << bl
    end
    [lines, o]
  end

end; end; end
