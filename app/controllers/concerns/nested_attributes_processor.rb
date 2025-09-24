module NestedAttributesProcessor
  extend ActiveSupport::Concern

  private

  def process_pending_changes(params)
    Rails.logger.info "🔍 DEBUG: process_pending_changes called with params keys: #{params.keys}"
    # Return params as-is if no pending_changes
    return params.except(:pending_changes) unless params[:pending_changes].present?

    Rails.logger.info "🔍 DEBUG: pending_changes present, parsing JSON..."
    begin
      pending_changes = JSON.parse(params[:pending_changes])
      Rails.logger.info "🔍 DEBUG: Parsed pending_changes: #{pending_changes}"
    rescue JSON::ParserError
      Rails.logger.error "Failed to parse pending_changes JSON: #{params[:pending_changes]}"
      return params.except(:pending_changes)
    end

    # Start with base params (excluding pending_changes)
    merged_params = params.except(:pending_changes).to_h
    Rails.logger.info "🔍 DEBUG: Base merged_params keys: #{merged_params.keys}"

    # Process parent field changes
    if pending_changes['parent']
      merged_params.merge!(pending_changes['parent'])
    end

    # Process parent_attributes (alternative format)
    if pending_changes['parent_attributes']
      Rails.logger.info "🔍 DEBUG: Processing parent_attributes: #{pending_changes['parent_attributes']}"
      pending_changes['parent_attributes'].each do |field_name, change_data|
        # Extract the actual field name from customer[field_name] format
        if field_name.match(/\[(.+)\]/)
          actual_field = $1
          Rails.logger.info "🔍 DEBUG: Setting #{actual_field} = #{change_data['new_value']}"
          merged_params[actual_field] = change_data['new_value']
        end
      end
    end

    # Process relationship changes for all relationships
    if pending_changes['relationships']
      pending_changes['relationships'].each do |relationship_name, changes|
        attributes_key = "#{relationship_name}_attributes"
        relationship_attributes = {}
        index = 0

        changes.each do |change|
          case change['action']
          when 'create'
            relationship_attributes[index.to_s] = change['attributes']
            index += 1
          when 'update'
            relationship_attributes[index.to_s] = change['attributes'].merge('id' => change['id'])
            index += 1
          when 'delete'
            relationship_attributes[index.to_s] = { 'id' => change['id'], '_destroy' => '1' }
            index += 1
          end
        end

        merged_params[attributes_key] = relationship_attributes unless relationship_attributes.empty?
      end
    end

    # Process direct attributes format (addresses_attributes, etc.)
    # Only process keys that haven't been handled above
    unprocessed_keys = pending_changes.keys - ['parent', 'parent_attributes', 'relationships']
    Rails.logger.info "🔍 DEBUG: Unprocessed keys: #{unprocessed_keys}"

    unprocessed_keys.each do |key|
      value = pending_changes[key]
      if key.end_with?('_attributes') && value.is_a?(Hash)
        Rails.logger.info "🔍 DEBUG: Processing #{key} with #{value.size} items"
        relationship_attributes = {}
        index = 0

        value.each do |record_id, record_data|
          # Convert the record data to the expected format
          clean_data = record_data.except('_method', 'authenticity_token', 'reason', 'reason_key')
          relationship_attributes[index.to_s] = clean_data
          index += 1
        end

        merged_params[key] = relationship_attributes unless relationship_attributes.empty?
        Rails.logger.info "🔍 DEBUG: Added #{key} with #{relationship_attributes.size} items to merged_params"
      else
        Rails.logger.warn "🔍 DEBUG: Skipping unhandled key: #{key}"
      end
    end

    Rails.logger.info "🔍 DEBUG: Final merged_params keys: #{merged_params.keys}"
    Rails.logger.info "🔍 DEBUG: Final merged_params: #{merged_params.to_h}"
    merged_params
  end
end