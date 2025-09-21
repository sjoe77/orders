import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pendingChanges"]
  static optionalTargets = ["reasonInput"]
  static values = {
    entityType: String,
    reasonKey: String
  }

  connect() {
    this.changes = JSON.parse(this.pendingChangesTarget.value || '{}')
    this.reasonKeyValue = this.reasonKeyValue || this.generateReasonKey()
    this.setupEventListeners()
  }

  // Generic event handlers
  handleRelationshipAction(event) {
    const { action, relationshipType, relationshipPattern, data, id } = event.detail

    switch(action) {
      case 'add':
        this.addRelated(relationshipType, relationshipPattern, data)
        break
      case 'update':
        this.updateRelated(relationshipType, relationshipPattern, id, data)
        break
      case 'remove':
        this.removeRelated(relationshipType, relationshipPattern, id)
        break
      case 'link':
        this.linkRelated(relationshipType, data)
        break
      case 'unlink':
        this.unlinkRelated(relationshipType, data)
        break
    }
  }

  // Pattern-specific handlers
  addRelated(relationshipType, pattern, data) {
    switch(pattern) {
      case 'nested_attributes':
        this.addNestedAttribute(relationshipType, data)
        break
      case 'independent_save':
        this.createIndependent(relationshipType, data)
        break
      case 'many_to_many':
        this.linkRelated(relationshipType, data)
        break
    }
  }

  updateRelated(relationshipType, pattern, id, data) {
    switch(pattern) {
      case 'nested_attributes':
        this.updateNestedAttribute(relationshipType, id, data)
        break
      case 'independent_save':
        // Updates handled in separate controllers
        break
      case 'many_to_many':
        // M:M doesn't have updates, only link/unlink
        break
    }
  }

  removeRelated(relationshipType, pattern, id) {
    switch(pattern) {
      case 'nested_attributes':
        this.removeNestedAttribute(relationshipType, id)
        break
      case 'independent_save':
        // Removes handled in separate controllers
        break
      case 'many_to_many':
        this.unlinkRelated(relationshipType, { source_id: this.data.get('entityId'), target_id: id })
        break
    }
  }

  // Nested attributes (Customer → Addresses)
  addNestedAttribute(relationshipType, data) {
    // Show modal for nested attribute creation
    this.showCreateModal(relationshipType, data)
  }

  createNestedAttribute(relationshipType, data) {
    const tempId = this.generateTempId()
    const attributesKey = `${relationshipType}_attributes`

    this.ensureKeyExists(attributesKey)
    this.changes[attributesKey][tempId] = {
      ...data,
      reason: this.getUserReason(),
      reason_key: this.reasonKeyValue
    }

    this.syncAndNotify(relationshipType, 'add', tempId, data)
  }

  updateNestedAttribute(relationshipType, id, data) {
    // For updates via events, show modal first
    if (arguments.length === 3 && typeof id === 'string' && typeof data === 'object' && !data.hasOwnProperty('reason')) {
      this.showEditModal(relationshipType, id, data)
      return
    }

    // Actual update (called from modal save)
    const attributesKey = `${relationshipType}_attributes`

    this.ensureKeyExists(attributesKey)
    this.changes[attributesKey][id] = {
      ...this.changes[attributesKey][id],
      ...data,
      reason: this.getUserReason(),
      reason_key: this.reasonKeyValue
    }

    this.syncAndNotify(relationshipType, 'update', id, data)
  }

  performUpdateNestedAttribute(relationshipType, id, data) {
    // This method performs the actual update (called from modal)
    const attributesKey = `${relationshipType}_attributes`

    this.ensureKeyExists(attributesKey)
    this.changes[attributesKey][id] = {
      ...this.changes[attributesKey][id],
      ...data,
      reason: this.getUserReason(),
      reason_key: this.reasonKeyValue
    }

    this.syncAndNotify(relationshipType, 'update', id, data)
  }

  removeNestedAttribute(relationshipType, id) {
    const attributesKey = `${relationshipType}_attributes`

    if (id.toString().startsWith('temp_')) {
      // Remove pending addition
      delete this.changes[attributesKey][id]
    } else {
      // Mark existing record for destruction
      this.ensureKeyExists(attributesKey)
      this.changes[attributesKey][id] = {
        id: id,
        _destroy: true,
        reason: this.getUserReason(),
        reason_key: this.reasonKeyValue
      }
    }

    this.syncAndNotify(relationshipType, 'remove', id)
  }

  // Many-to-many links (Product ↔ Categories)
  linkRelated(relationshipType, linkData) {
    const linksKey = `${relationshipType}_links`
    const linkId = `${linkData.source_id}_${linkData.target_id}`

    this.ensureKeyExists(linksKey)
    this.changes[linksKey][linkId] = {
      action: 'link',
      source_id: linkData.source_id,
      target_id: linkData.target_id,
      reason: this.getUserReason(),
      reason_key: this.reasonKeyValue
    }

    this.syncAndNotify(relationshipType, 'link', linkId, linkData)
  }

  unlinkRelated(relationshipType, linkData) {
    const linksKey = `${relationshipType}_links`
    const linkId = `${linkData.source_id}_${linkData.target_id}`

    this.ensureKeyExists(linksKey)
    this.changes[linksKey][linkId] = {
      action: 'unlink',
      source_id: linkData.source_id,
      target_id: linkData.target_id,
      reason: this.getUserReason(),
      reason_key: this.reasonKeyValue
    }

    this.syncAndNotify(relationshipType, 'unlink', linkId, linkData)
  }

  // Independent creation (Customer → Orders)
  createIndependent(relationshipType, data) {
    // Navigate to independent creation with context
    const entityId = this.data.get('entityId') || this.extractEntityId()
    const createUrl = `/${this.entityTypeValue}s/${entityId}/${relationshipType}/new`
    const params = new URLSearchParams({
      reason_key: this.reasonKeyValue,
      reason: this.getUserReason(),
      return_url: window.location.href
    })

    window.open(`${createUrl}?${params}`, '_blank')
  }

  // State management
  getAllChanges() {
    return { ...this.changes }
  }

  clearChanges() {
    this.changes = {}
    this.syncToHiddenField()
  }

  // Utility methods
  generateTempId() {
    return `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  generateReasonKey() {
    return `edit_session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  getUserReason() {
    // For relationship operations, use a default reason since reasonInput is only available in update modal
    if (!this.hasReasonInputTarget) {
      return "Relationship updated via web interface"
    }
    return this.reasonInputTarget?.value || "Updated via web interface"
  }

  ensureKeyExists(key) {
    if (!this.changes[key]) {
      this.changes[key] = {}
    }
  }

  syncAndNotify(relationshipType, action, id, data) {
    this.syncToHiddenField()
    this.dispatch("graph-changed", {
      detail: {
        entityType: this.entityTypeValue,
        relationshipType,
        action,
        id,
        data,
        allChanges: this.changes
      }
    })
  }

  syncToHiddenField() {
    this.pendingChangesTarget.value = JSON.stringify(this.changes)
  }

  extractEntityId() {
    // Extract from URL or form if not provided in data
    const match = window.location.pathname.match(/\/(\w+)\/(\d+)/)
    return match ? match[2] : null
  }

  setupEventListeners() {
    this.element.addEventListener('relationship:action', this.handleRelationshipAction.bind(this))
    this.element.addEventListener('modal-dialog:save', this.handleModalSave.bind(this))
    this.element.addEventListener('modal-dialog:cancel', this.handleModalCancel.bind(this))
  }

  // Modal management methods
  showCreateModal(relationshipType, data = {}) {
    const modalId = this.getModalId(relationshipType)
    const modal = document.getElementById(modalId)

    if (modal) {
      const controller = this.application.getControllerForElementAndIdentifier(modal, 'modal-dialog')
      if (controller) {
        // Clear any existing data
        controller.clearForm()
        // Show the modal
        controller.show()

        // Store context for when modal is saved
        this.currentModalContext = {
          relationshipType,
          action: 'create',
          data
        }
      }
    }
  }

  showEditModal(relationshipType, id, data = {}) {
    const modalId = this.getModalId(relationshipType)
    const modal = document.getElementById(modalId)

    if (modal) {
      // Update modal title for editing
      const titleElement = modal.querySelector('.modal-title')
      if (titleElement && relationshipType === 'addresses') {
        titleElement.textContent = 'Edit Address'
      }

      const controller = this.application.getControllerForElementAndIdentifier(modal, 'modal-dialog')
      if (controller) {
        // Populate form with existing data
        controller.populateForm(data)
        // Show the modal
        controller.show()

        // Store context for when modal is saved
        this.currentModalContext = {
          relationshipType,
          action: 'edit',
          id,
          data
        }
      }
    }
  }

  getModalId(relationshipType) {
    // Map relationship types to modal IDs
    const modalMap = {
      'addresses': 'addressModal',
      'orders': 'orderModal',
      'products': 'productModal'
    }
    return modalMap[relationshipType] || `${relationshipType}Modal`
  }

  // Handle modal save events
  handleModalSave(event) {
    const { modalId, formData, form } = event.detail

    if (!this.currentModalContext) return

    const { relationshipType, action, id, data } = this.currentModalContext

    if (action === 'create') {
      // Convert FormData to object
      const formObject = {}
      for (let [key, value] of formData.entries()) {
        formObject[key] = value
      }

      // Create the nested attribute
      this.createNestedAttribute(relationshipType, formObject)
    } else if (action === 'edit') {
      // Convert FormData to object
      const formObject = {}
      for (let [key, value] of formData.entries()) {
        formObject[key] = value
      }

      // Update the nested attribute
      this.performUpdateNestedAttribute(relationshipType, id, formObject)
    }

    // Hide the modal
    const modal = document.getElementById(modalId)
    if (modal) {
      const controller = this.application.getControllerForElementAndIdentifier(modal, 'modal-dialog')
      if (controller) {
        controller.hide()
      }
    }

    // Clear context
    this.currentModalContext = null
  }

  // Handle modal cancel events
  handleModalCancel(event) {
    // Clear context
    this.currentModalContext = null
  }

  // Modal workflow methods
  prepareUpdate(event) {
    event.preventDefault()
    // Modal is already being shown by Bootstrap
    // Focus on the reason input when modal opens
    document.getElementById('modalAuditReason').focus()
  }

  performUpdate(event) {
    event.preventDefault()

    // Get the reason from the modal
    const reason = document.getElementById('modalAuditReason').value
    if (!reason.trim()) {
      alert('Please provide a reason for the changes.')
      return
    }

    // Set the reason in a hidden field (create one if needed since reasonInput is in modal)
    let reasonField = document.querySelector('input[name="customer[audit_reason]"]')
    if (!reasonField) {
      reasonField = document.createElement('input')
      reasonField.type = 'hidden'
      reasonField.name = 'customer[audit_reason]'
      document.getElementById('customer_form').appendChild(reasonField)
    }
    reasonField.value = reason

    // Submit the form
    const form = document.getElementById('customer_form')
    if (form) {
      form.submit()
    }

    // Close the modal
    const modal = bootstrap.Modal.getInstance(document.getElementById('updateModal'))
    if (modal) {
      modal.hide()
    }
  }
}