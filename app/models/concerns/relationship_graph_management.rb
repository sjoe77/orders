module RelationshipGraphManagement
  extend ActiveSupport::Concern

  included do
    attr_accessor :reason, :reason_key
    before_save :set_paper_trail_reason
  end

  class_methods do
    def manages_relationships(*relationships)
      relationships.each do |relationship|
        relationship_config = relationship.is_a?(Hash) ? relationship : { relationship => :nested_attributes }

        relationship_config.each do |rel_name, pattern|
          case pattern
          when :nested_attributes
            accepts_nested_attributes_for rel_name, reject_if: :all_blank, allow_destroy: true
          when :many_to_many
            define_method "handle_#{rel_name}_links" do |links_data, reason_key|
              RelationshipGraphManagement.handle_many_to_many_links(
                self, rel_name, links_data, reason_key
              )
            end
          when :independent_save
            # Independent saves handled by their own controllers
            # No special setup needed here
          end
        end
      end
    end
  end

  def update_with_graph_changes(params, pending_changes_json)
    reason_key = params[:reason_key] || SecureRandom.uuid
    pending_changes = JSON.parse(pending_changes_json || '{}')

    ActiveRecord::Base.transaction do
      self.reason_key = reason_key

      # Handle nested attributes
      nested_params = extract_nested_attributes(pending_changes)
      merged_params = params.merge(nested_params)

      # Handle M:M relationships
      many_to_many_changes = extract_many_to_many_changes(pending_changes)

      if update(merged_params)
        # Process M:M links after successful save
        many_to_many_changes.each do |relationship, links|
          send("handle_#{relationship}_links", links, reason_key)
        end
        true
      else
        false
      end
    end
  end

  private

  def extract_nested_attributes(pending_changes)
    pending_changes.select { |key, _| key.end_with?('_attributes') }
  end

  def extract_many_to_many_changes(pending_changes)
    pending_changes.select { |key, _| key.end_with?('_links') }
  end

  def set_paper_trail_reason
    if reason.present? && defined?(PaperTrail)
      PaperTrail.request.controller_info = {
        reason: reason,
        reason_key: reason_key
      }
    end
  end

  # Class method for M:M handling
  module ClassMethods
    def handle_many_to_many_links(parent_object, relationship_name, links_data, reason_key)
      links_data.each do |link_id, link_data|
        case link_data['action']
        when 'link'
          create_many_to_many_link(parent_object, relationship_name, link_data, reason_key)
        when 'unlink'
          destroy_many_to_many_link(parent_object, relationship_name, link_data, reason_key)
        end
      end
    end

    def create_many_to_many_link(parent_object, relationship_name, link_data, reason_key)
      join_model = get_join_model(parent_object.class, relationship_name)
      foreign_keys = get_foreign_keys(parent_object.class, relationship_name)

      join_model.create!(
        foreign_keys[:parent] => parent_object.id,
        foreign_keys[:related] => link_data['target_id'],
        reason: link_data['reason'],
        reason_key: reason_key
      )
    end

    def destroy_many_to_many_link(parent_object, relationship_name, link_data, reason_key)
      join_model = get_join_model(parent_object.class, relationship_name)
      foreign_keys = get_foreign_keys(parent_object.class, relationship_name)

      join_model.where(
        foreign_keys[:parent] => parent_object.id,
        foreign_keys[:related] => link_data['target_id']
      ).update_all(
        reason: link_data['reason'],
        reason_key: reason_key,
        deleted_at: Time.current
      )
    end

    # Convention-based helpers
    def get_join_model(parent_class, relationship_name)
      parent_class.reflect_on_association(relationship_name).through_reflection.klass
    end

    def get_foreign_keys(parent_class, relationship_name)
      association = parent_class.reflect_on_association(relationship_name)
      through_association = association.through_reflection

      {
        parent: through_association.foreign_key,
        related: association.foreign_key
      }
    end
  end

  # Include class methods
  def self.included(base)
    base.extend(ClassMethods)
  end
end