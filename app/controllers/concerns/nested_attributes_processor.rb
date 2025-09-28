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
          # Convert the record data to the expected format, preserving _destroy for deletes
          clean_data = record_data.except('_method', 'authenticity_token', 'reason', 'reason_key')

          # Handle delete operations - ensure _destroy flag is preserved
          if record_data['_destroy'] == '1' || record_data['_destroy'] == true
            clean_data['_destroy'] = '1'
          end

          relationship_attributes[index.to_s] = clean_data
          index += 1
        end

        merged_params[key] = relationship_attributes unless relationship_attributes.empty?
        Rails.logger.info "🔍 DEBUG: Added #{key} with #{relationship_attributes.size} items to merged_params"
      elsif key.end_with?('_ids') && value.is_a?(Array)
        # Handle M:M relationship IDs (e.g., categories_ids, products_ids)
        Rails.logger.info "🔍 DEBUG: Processing M:M relationship #{key} with #{value.size} IDs: #{value}"
        merged_params[key] = value.map(&:to_s).reject(&:blank?)
        Rails.logger.info "🔍 DEBUG: Added #{key} = #{merged_params[key]} to merged_params"
      else
        Rails.logger.warn "🔍 DEBUG: Skipping unhandled key: #{key}"
      end
    end

    Rails.logger.info "🔍 DEBUG: Final merged_params keys: #{merged_params.keys}"
    Rails.logger.info "🔍 DEBUG: Final merged_params: #{merged_params.to_h}"
    merged_params
  end

  # Enhanced validation for M:M relationship patches to support conflict resolution
  def validate_mm_relationship_patches(pending_changes)
    validation_results = {}

    return validation_results unless pending_changes.is_a?(Hash)

    pending_changes.each do |key, value|
      if key.end_with?('_ids') && value.is_a?(Array)
        relationship_name = key.gsub('_ids', '')
        validation_results[relationship_name] = validate_relationship_ids(relationship_name, value)
      end
    end

    validation_results
  end

  def validate_relationship_ids(relationship_name, id_array)
    result = {
      valid_ids: [],
      invalid_ids: [],
      relationship_class: nil,
      validation_errors: []
    }

    # Try to determine the relationship class
    begin
      # Convert relationship name to class (e.g., 'categories' -> Category)
      class_name = relationship_name.singularize.camelize
      relationship_class = class_name.constantize
      result[:relationship_class] = relationship_class

      # Validate each ID exists in the database
      valid_ids = relationship_class.where(id: id_array).pluck(:id).map(&:to_s)
      result[:valid_ids] = valid_ids
      result[:invalid_ids] = id_array.map(&:to_s) - valid_ids

      if result[:invalid_ids].any?
        result[:validation_errors] << "Invalid #{relationship_name} IDs: #{result[:invalid_ids].join(', ')}"
      end

    rescue NameError => e
      result[:validation_errors] << "Could not find relationship class for '#{relationship_name}': #{e.message}"
    end

    result
  end

  # Extract M:M relationship patches for conflict analysis
  def extract_mm_relationship_patches(params)
    mm_patches = {}

    # Extract from pending_changes if present
    if params[:pending_changes].present?
      begin
        pending_changes = JSON.parse(params[:pending_changes])

        pending_changes.each do |key, value|
          if key.end_with?('_ids') && value.is_a?(Array)
            relationship_name = key.gsub('_ids', '')
            mm_patches[relationship_name] = {
              intended_ids: value.map(&:to_s).reject(&:blank?),
              source: 'pending_changes',
              patch_timestamp: Time.current.iso8601
            }
          end
        end
      rescue JSON::ParserError
        Rails.logger.error "Failed to parse pending_changes for M:M extraction: #{params[:pending_changes]}"
      end
    end

    # Also check for direct relationship ID parameters
    params.each do |key, value|
      if key.to_s.end_with?('_ids') && value.is_a?(Array)
        relationship_name = key.to_s.gsub('_ids', '')
        mm_patches[relationship_name] ||= {}
        mm_patches[relationship_name].merge!({
          intended_ids: value.map(&:to_s).reject(&:blank?),
          source: 'direct_params',
          patch_timestamp: Time.current.iso8601
        })
      end
    end

    mm_patches
  end

  # Support method for enterprise audit trail integration
  def build_mm_patch_metadata(params, entity)
    metadata = {
      mm_patches: extract_mm_relationship_patches(params),
      validation_results: {},
      entity_class: entity.class.name,
      entity_id: entity.id,
      patch_applied_at: Time.current.iso8601
    }

    # Validate the extracted patches
    if params[:pending_changes].present?
      begin
        pending_changes = JSON.parse(params[:pending_changes])
        metadata[:validation_results] = validate_mm_relationship_patches(pending_changes)
      rescue JSON::ParserError
        metadata[:validation_errors] = ["Failed to parse pending_changes JSON"]
      end
    end

    metadata
  end
end