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

    merged_params
  end
end