module NestedAttributesProcessor
  extend ActiveSupport::Concern

  private

  def process_pending_changes(params)
    # Return params as-is if no pending_changes
    return params.except(:pending_changes) unless params[:pending_changes].present?

    begin
      pending_changes = JSON.parse(params[:pending_changes])
    rescue JSON::ParserError
      Rails.logger.error "Failed to parse pending_changes JSON: #{params[:pending_changes]}"
      return params.except(:pending_changes)
    end

    # Start with base params (excluding pending_changes)
    merged_params = params.except(:pending_changes).to_h

    # Process parent field changes
    if pending_changes['parent']
      merged_params.merge!(pending_changes['parent'])
    end

    # Process parent_attributes (alternative format)
    if pending_changes['parent_attributes']
      pending_changes['parent_attributes'].each do |field_name, change_data|
        # Extract the actual field name from customer[field_name] format
        if field_name.match(/\[(.+)\]/)
          actual_field = $1
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
    pending_changes.each do |key, value|
      if key.end_with?('_attributes') && value.is_a?(Hash)
        relationship_attributes = {}
        index = 0

        value.each do |record_id, record_data|
          # Convert the record data to the expected format
          clean_data = record_data.except('_method', 'authenticity_token', 'reason', 'reason_key')
          relationship_attributes[index.to_s] = clean_data
          index += 1
        end

        merged_params[key] = relationship_attributes unless relationship_attributes.empty?
      end
    end

    merged_params
  end
end