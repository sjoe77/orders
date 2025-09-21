# Object Graph Management Patterns for Enterprise Rails Applications

## Overview

This document outlines comprehensive patterns for managing complex object graphs in Rails applications with enterprise-grade audit trails, optimistic concurrency control, and atomic save operations. These patterns provide a foundation for building maintainable, auditable systems that handle complex relationships while preserving data integrity.

## Core Principles

### 1. Parent-Managed Atomic Saves
All changes within an object graph are saved atomically when the parent object is saved. This ensures data consistency and provides clear audit trails.

### 2. Draft vs Persisted State Management
- **Draft Objects**: New, unsaved objects don't show relationship tables until persisted
- **Persisted Objects**: Saved objects display full relationship management capabilities

### 3. Granular Change Tracking
Every save operation is tracked with:
- Common reason key linking related changes
- Individual change records for each modified object
- Audit trail showing complete transaction context

## Relationship Management Patterns

### 1. Belongs To Relationship (1:M) - Simple Objects

**Example**: Customer → Addresses

**UI Pattern**:
- Show addresses table only after customer is persisted
- "Add" button opens dialog to add address to customer form
- Address changes remain unsaved until customer save
- All address modifications saved atomically with customer

**Implementation**:
```ruby
# Customer update with nested addresses
def update
  reason_key = SecureRandom.uuid

  ActiveRecord::Base.transaction do
    @customer.reason = "Customer and addresses update - #{reason_key}"

    # Nested attributes handle address creation/updates
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Customer and addresses saved successfully"
    else
      render :edit
    end
  end
rescue ActiveRecord::RecordInvalid => e
  render :edit, alert: "Update failed: #{e.message}"
end

private

def customer_params
  params.require(:customer).permit(:name, :email,
    addresses_attributes: [:id, :street, :city, :state, :zip, :_destroy])
end
```

### 2. Belongs To Relationship (1:M) - Complex Objects

**Example**: Customer → Orders (with Order Line Items)

**UI Pattern**:
- "Add" button on orders table opens new browser tab
- Order page contains line items table with its own "Add" functionality
- Order save includes all line items atomically
- Return to customer page with new order row added

**Implementation**:
```ruby
# Order with line items
def create
  ActiveRecord::Base.transaction do
    @order = @customer.orders.build(order_params)
    @order.reason = "Created order from customer page"

    if @order.save
      # Line items are saved as part of nested attributes
      redirect_to customer_path(@customer), notice: "Order created successfully"
    else
      render :new
    end
  end
rescue ActiveRecord::RecordInvalid => e
  render :new, alert: "Failed to create order: #{e.message}"
end
```

### 3. Many-to-Many Relationships (M:M)

**Example**: Product ↔ Categories

**UI Pattern**:
- Both sides are independent entities with their own main pages
- "Link" button (not "Add") opens dialog with existing objects
- Checkboxes for selecting multiple items to link/unlink
- Links save immediately with confirmation

**Implementation**:
```ruby
# Product-Category linking
def link_categories
  ActiveRecord::Base.transaction do
    reason = "Updated product categories from product page"

    # Remove existing links
    @product.product_categories.destroy_all

    # Create new links
    category_ids.each do |category_id|
      @product.product_categories.create!(
        category_id: category_id,
        reason: reason
      )
    end

    render json: { success: true, message: "Categories updated successfully" }
  end
rescue => e
  render json: { error: e.message }
end
```

## PaperTrail Integration with Common Reason Keys

### Configuration

```ruby
# In models
class Customer < ApplicationRecord
  has_paper_trail

  attr_accessor :reason

  before_save :set_paper_trail_reason

  private

  def set_paper_trail_reason
    PaperTrail.request.whodunnit = current_user&.id
    PaperTrail.request.controller_info = { reason: reason }
  end
end

class Address < ApplicationRecord
  belongs_to :customer
  has_paper_trail

  attr_accessor :reason
  before_save :set_paper_trail_reason

  private

  def set_paper_trail_reason
    PaperTrail.request.controller_info = { reason: reason }
  end
end
```

### Atomic Save with Shared Reason

```ruby
class CustomersController < ApplicationController
  def update
    reason_key = SecureRandom.uuid

    ActiveRecord::Base.transaction do
      # Set common reason for all changes in this transaction
      @customer.reason = "Customer update - #{reason_key}"

      if @customer.update(customer_params)
        # Handle nested address updates
        if params[:addresses_attributes]
          params[:addresses_attributes].each do |id, address_attrs|
            address = @customer.addresses.find(id)
            address.reason = "Address update - #{reason_key}"
            address.update!(address_attrs)
          end
        end

        redirect_to @customer, notice: "Customer updated successfully"
      else
        render :edit
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render :edit, alert: "Update failed: #{e.message}"
  end
end
```

## Optimistic Concurrency Control

### Model Setup

```ruby
class Customer < ApplicationRecord
  # Enable optimistic locking
  self.locking_column = :lock_version

  def stale?
    changed? && lock_version_changed?
  end
end
```

### Stale Save Detection

```ruby
def update
  begin
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Customer updated successfully"
    else
      render :edit
    end
  rescue ActiveRecord::StaleObjectError
    # Reload fresh data
    @customer.reload

    flash.now[:alert] = "Someone else has updated this customer. Please review the current data and try again."
    render :edit
  end
end
```

### Multi-Level Stale Detection

```ruby
# In forms, include lock_version for all objects
<%= form.hidden_field :lock_version %>

# Check for stale objects at each level
def update_order_with_line_items
  ActiveRecord::Base.transaction do
    # Check order staleness
    if @order.lock_version != params[:order][:lock_version].to_i
      raise ActiveRecord::StaleObjectError, "Order has been modified"
    end

    # Check line items staleness
    params[:order][:line_items_attributes]&.each do |id, attrs|
      line_item = @order.line_items.find(id)
      if line_item.lock_version != attrs[:lock_version].to_i
        raise ActiveRecord::StaleObjectError, "Line item #{id} has been modified"
      end
    end

    @order.update!(order_params)
  end
rescue ActiveRecord::StaleObjectError => e
  flash.now[:alert] = "Stale data detected: #{e.message}"
  @order.reload
  render :edit
end
```

## Timeline View Implementation

### Audit Trail Query

```ruby
class AuditService
  def self.customer_timeline(customer)
    # Get customer changes
    customer_versions = customer.versions.includes(:item)

    # Get level-1 association changes (addresses, orders)
    address_versions = PaperTrail::Version.where(
      item_type: 'Address',
      item_id: customer.address_ids
    )

    order_versions = PaperTrail::Version.where(
      item_type: 'Order',
      item_id: customer.order_ids
    )

    # Combine and sort by created_at
    all_versions = (customer_versions + address_versions + order_versions)
                  .sort_by(&:created_at)
                  .reverse

    group_by_reason(all_versions)
  end

  private

  def self.group_by_reason(versions)
    versions.group_by do |version|
      version.controller_info&.dig('reason') || 'Unknown reason'
    end
  end
end
```

### Timeline Display

```erb
<!-- Timeline view -->
<div class="timeline">
  <% AuditService.customer_timeline(@customer).each do |reason, versions| %>
    <div class="timeline-group">
      <h6><%= reason %></h6>
      <small class="text-muted"><%= versions.first.created_at.strftime("%B %d, %Y at %I:%M %p") %></small>

      <ul class="list-group mt-2">
        <% versions.each do |version| %>
          <li class="list-group-item">
            <strong><%= version.item_type %></strong>
            <span class="badge bg-<%= version_badge_color(version.event) %>">
              <%= version.event.humanize %>
            </span>
            <!-- Show specific changes -->
            <% if version.changeset.present? %>
              <ul class="small mt-1">
                <% version.changeset.each do |field, (old_val, new_val)| %>
                  <li><strong><%= field.humanize %>:</strong> <%= old_val %> → <%= new_val %></li>
                <% end %>
              </ul>
            <% end %>
          </li>
        <% end %>
      </ul>
    </div>
  <% end %>
</div>
```

## Bootstrap UI Implementation

### Responsive Relationship Tables

```erb
<!-- Customer edit page with related objects -->
<div class="container-fluid">
  <% if @customer.persisted? %>
    <%= render TabsComponent.new(id: "customer_tabs") do |tabs| %>
      <% tabs.with_tab(title: "Addresses", active: true) do %>
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h6>Addresses</h6>
          <button class="btn btn-sm btn-outline-primary"
                  data-bs-toggle="modal"
                  data-bs-target="#addressModal">
            <i class="bi bi-plus-circle"></i> Add Address
          </button>
        </div>
        <%= render 'addresses/table', addresses: @customer.addresses %>
      <% end %>

      <% tabs.with_tab(title: "Orders") do %>
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h6>Orders</h6>
          <a href="<%= new_customer_order_path(@customer) %>"
             class="btn btn-sm btn-outline-primary"
             target="_blank">
            <i class="bi bi-plus-circle"></i> Add Order
          </a>
        </div>
        <%= render 'orders/table', orders: @customer.orders %>
      <% end %>
    <% end %>
  <% else %>
    <div class="alert alert-info">
      <i class="bi bi-info-circle"></i>
      Save the customer first to manage related addresses and orders.
    </div>
  <% end %>
</div>
```

### Linking Dialog for M:M Relationships

```erb
<!-- Category linking modal for Product -->
<div class="modal fade" id="categoryModal">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Link Categories</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <%= form_with url: link_categories_product_path(@product),
                      method: :patch,
                      local: false do |form| %>
          <% Category.all.each do |category| %>
            <div class="form-check">
              <%= check_box_tag 'category_ids[]',
                                category.id,
                                @product.categories.include?(category),
                                id: "category_#{category.id}",
                                class: 'form-check-input' %>
              <%= label_tag "category_#{category.id}",
                           category.name,
                           class: 'form-check-label' %>
            </div>
          <% end %>
        <% end %>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
        <button type="submit" class="btn btn-primary">Save Links</button>
      </div>
    </div>
  </div>
</div>
```

## Enterprise Considerations

### Compliance and Audit Requirements

1. **Complete Audit Trail**: Every change is tracked with user, timestamp, and business reason
2. **Data Integrity**: Atomic transactions ensure consistency across related objects
3. **Conflict Resolution**: Optimistic locking prevents data corruption from concurrent edits
4. **Regulatory Compliance**: Audit logs provide evidence for compliance reporting

### Performance Optimizations

1. **Lazy Loading**: Relationship tables load on-demand via tabs
2. **Pagination**: Large datasets use cursor-based pagination
3. **Caching**: Frequently accessed audit data uses Rails cache
4. **Background Processing**: Complex audit reports run via background jobs

### Security Considerations

1. **Authorization**: Each relationship action checked against user permissions
2. **Input Validation**: All nested attributes validated before save
3. **SQL Injection Prevention**: Using parameterized queries throughout
4. **Audit Log Protection**: Version records are immutable after creation

## Summary

This object graph management pattern provides:

- **Atomic Operations**: All related changes saved together or rolled back
- **Clear Audit Trails**: Every change linked by common reason keys
- **Conflict Prevention**: Optimistic locking at all levels
- **Flexible UI**: Different patterns for different relationship types
- **Enterprise Ready**: Meets audit, compliance, and performance requirements

The pattern scales from simple 1:M relationships to complex object graphs while maintaining data integrity and providing comprehensive audit capabilities suitable for enterprise applications.