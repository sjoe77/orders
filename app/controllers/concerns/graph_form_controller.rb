module GraphFormController
  extend ActiveSupport::Concern

  def update_with_graph
    reason = params.dig(resource_name, :audit_reason) || "Updated via web interface"
    pending_changes = params.dig(resource_name, :pending_changes)

    resource.reason = reason

    if resource.update_with_graph_changes(resource_params, pending_changes)
      redirect_to resource, notice: "#{resource_name.humanize} updated successfully"
    else
      render :edit
    end
  rescue ActiveRecord::StaleObjectError
    resource.reload
    flash.now[:alert] = "Someone else has updated this record. Please review and try again."
    render :edit
  end

  private

  def resource
    instance_variable_get("@#{resource_name}")
  end

  def resource_name
    controller_name.singularize
  end

  def resource_params
    params.require(resource_name).permit(*permitted_attributes)
  end

  # Override in controllers
  def permitted_attributes
    raise NotImplementedError, "Define permitted_attributes in #{self.class}"
  end
end