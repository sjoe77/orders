import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["addressesContainer"]
  static optionalTargets = ["pendingChanges", "reasonInput"]
  static values = {
    entityType: String,
    reasonKey: String
  }

  connect() {
    // Only initialize if we have the required elements for form functionality
    if (this.hasPendingChangesTarget) {
      this.changes = JSON.parse(this.pendingChangesTarget.value || '{}')
      this.reasonKeyValue = this.reasonKeyValue || this.generateReasonKey()
      this.originalFormData = this.captureOriginalFormData()
      this.setupEventListeners()
      this.setupParentFieldTracking()
    }
  }

  captureOriginalFormData() {
    // Capture initial state for patch comparison
    const form = this.element.querySelector('form')
    if (!form) return {}

    const formData = new FormData(form)
    const original = {}

    for (let [key, value] of formData.entries()) {
      original[key] = value
    }

    console.log('📸 Captured original form data:', original)
    return original
  }

  setupParentFieldTracking() {
    // Track changes to parent entity fields (customer fields)
    const form = this.element.querySelector('form')
    if (!form) return

    const parentFields = form.querySelectorAll('input:not([name*="addresses_attributes"]), select:not([name*="addresses_attributes"]), textarea:not([name*="addresses_attributes"])')

    parentFields.forEach(field => {
      // Only use 'change' event to avoid capturing every keystroke
      field.addEventListener('change', this.handleParentFieldChange.bind(this))
    })
  }

  handleParentFieldChange(event) {
    const field = event.target
    const fieldName = field.name
    const newValue = field.value
    const originalValue = this.originalFormData[fieldName]

    if (newValue !== originalValue) {
      // Track parent field change
      if (!this.changes.parent_attributes) {
        this.changes.parent_attributes = {}
      }

      this.changes.parent_attributes[fieldName] = {
        original_value: originalValue,
        new_value: newValue,
        reason: this.getUserReason(),
        reason_key: this.reasonKeyValue
      }

      console.log(`🔧 PARENT FIELD CHANGE:`, {
        field: fieldName,
        originalValue: originalValue,
        newValue: newValue,
        allChanges: this.changes
      })

      this.syncToHiddenField()
    }
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
    const patch = {
      ...data,
      reason: this.getUserReason(),
      reason_key: this.reasonKeyValue
    }

    this.changes[attributesKey][tempId] = patch

    // Baby step: Log patch to console for debugging
    console.log(`🔧 CREATE ${relationshipType} patch:`, {
      action: 'create',
      tempId: tempId,
      relationshipType: relationshipType,
      patch: patch,
      allChanges: this.changes
    })

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

    // Get original values for patch comparison
    const originalData = this.changes[attributesKey][id] || {}

    const patch = {
      ...originalData,
      ...data,
      id: id, // Ensure ID is included for existing records
      reason: this.getUserReason(),
      reason_key: this.reasonKeyValue
    }

    this.changes[attributesKey][id] = patch

    // Baby step: Log detailed patch for debugging
    console.log(`🔧 UPDATE ${relationshipType} patch:`, {
      action: 'update',
      id: id,
      relationshipType: relationshipType,
      originalData: originalData,
      newData: data,
      finalPatch: patch,
      allChanges: this.changes
    })

    this.syncAndNotify(relationshipType, 'update', id, data)
  }

  removeNestedAttribute(relationshipType, id) {
    const attributesKey = `${relationshipType}_attributes`

    if (id.toString().startsWith('temp_')) {
      // Remove pending addition
      console.log(`🔧 DELETE ${relationshipType} patch (temp):`, {
        action: 'delete_temp',
        id: id,
        relationshipType: relationshipType,
        note: 'Removing pending addition before save'
      })
      delete this.changes[attributesKey][id]
    } else {
      // Mark existing record for destruction
      this.ensureKeyExists(attributesKey)
      const deletePatch = {
        id: id,
        _destroy: true,
        reason: this.getUserReason(),
        reason_key: this.reasonKeyValue
      }

      this.changes[attributesKey][id] = deletePatch

      console.log(`🔧 DELETE ${relationshipType} patch:`, {
        action: 'delete',
        id: id,
        relationshipType: relationshipType,
        patch: deletePatch,
        allChanges: this.changes
      })
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
    // Initialize changes if it doesn't exist
    if (!this.changes) {
      this.changes = {}
    }
    if (!this.changes[key]) {
      this.changes[key] = {}
    }
  }

  syncAndNotify(relationshipType, action, id, data) {
    this.syncToHiddenField()

    // Generate comprehensive patch summary
    this.logPatchSummary()

    // Replay patch on relationship table
    this.replayPatchOnTable(relationshipType, action, id, data)

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

  replayPatchOnTable(relationshipType, action, id, data) {
    // Find the relationship table that needs updating
    const tableContainer = document.querySelector(`[data-relationship-type="${relationshipType}"]`)
    if (!tableContainer) return

    const table = tableContainer.querySelector('table tbody')
    if (!table) return

    console.log(`🔄 Replaying ${action} patch on ${relationshipType} table for ID: ${id}`)

    switch (action) {
      case 'add':
        this.addTableRow(table, relationshipType, id, data)
        break
      case 'update':
        this.updateTableRow(table, relationshipType, id, data)
        break
      case 'remove':
        this.removeTableRow(table, relationshipType, id)
        break
    }
  }

  addTableRow(table, relationshipType, tempId, data) {
    // For new records, add a temporary row
    const row = document.createElement('tr')
    row.setAttribute('data-record-id', tempId)
    row.setAttribute('data-temp-record', 'true')

    // Build cells based on the data
    row.innerHTML = this.buildTableRowHTML(relationshipType, data)

    table.appendChild(row)
    console.log(`✅ Added new row for ${relationshipType}:`, tempId)
  }

  updateTableRow(table, relationshipType, id, data) {
    // Find existing row and update it
    const row = table.querySelector(`tr[data-record-id="${id}"]`)
    if (row) {
      // Update the row contents with new data
      row.innerHTML = this.buildTableRowHTML(relationshipType, data)
      console.log(`✅ Updated row for ${relationshipType}:`, id)
    }
  }

  removeTableRow(table, relationshipType, id) {
    const row = table.querySelector(`tr[data-record-id="${id}"]`)
    if (row) {
      row.remove()
      console.log(`✅ Removed row for ${relationshipType}:`, id)
    }
  }

  buildTableRowHTML(relationshipType, data) {
    // Build table row HTML based on relationship type and data
    if (relationshipType === 'addresses') {
      return this.buildAddressRowHTML(data)
    }

    // Add other relationship types as needed
    return '<td colspan="100%">Updated via patch</td>'
  }

  buildAddressRowHTML(data) {
    return `
      <td>${data.address_type_nm || ''}</td>
      <td>${data.address_line1_txt || ''}</td>
      <td>${data.city_nm || ''}</td>
      <td>${data.state_nm || ''}</td>
      <td>${data.postal_code_nm || ''}</td>
      <td>${data.is_default_flag ? 'Yes' : 'No'}</td>
    `
  }

  logPatchSummary() {
    const summary = {
      reason_key: this.reasonKeyValue,
      timestamp: new Date().toISOString(),
      parent_changes: this.changes.parent_attributes || {},
      relationship_changes: {}
    }

    // Summarize relationship changes
    Object.keys(this.changes).forEach(key => {
      if (key.endsWith('_attributes')) {
        const relationshipType = key.replace('_attributes', '')
        const changes = this.changes[key]

        summary.relationship_changes[relationshipType] = {
          creates: [],
          updates: [],
          deletes: []
        }

        Object.entries(changes).forEach(([id, changeData]) => {
          if (changeData._destroy) {
            summary.relationship_changes[relationshipType].deletes.push({
              id: id,
              data: changeData
            })
          } else if (id.startsWith('temp_')) {
            summary.relationship_changes[relationshipType].creates.push({
              tempId: id,
              data: changeData
            })
          } else {
            summary.relationship_changes[relationshipType].updates.push({
              id: id,
              data: changeData
            })
          }
        })
      }
    })

    console.log('📋 PATCH SUMMARY:', summary)
  }

  syncToHiddenField() {
    // Everything stored in single JSON field - clean and simple!
    if (this.hasPendingChangesTarget && this.changes) {
      this.pendingChangesTarget.value = JSON.stringify(this.changes)
    }
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
    console.log(`🚀 showEditModal called with:`, { relationshipType, id, data })

    const modalId = this.getModalId(relationshipType)
    console.log(`🔍 Looking for modal with ID: ${modalId}`)

    const modal = document.getElementById(modalId)
    console.log(`🔍 Found modal element:`, modal)

    if (modal) {
      // Update modal title for editing
      const titleElement = modal.querySelector('.modal-title')
      if (titleElement && relationshipType === 'addresses') {
        titleElement.textContent = 'Edit Address'
      }

      // Get the turbo frame inside the modal for loading the form
      const formFrame = modal.querySelector('turbo-frame[id$="_form"]')
      console.log(`🔍 Found form frame:`, formFrame)

      if (formFrame) {
        // Merge server data with pending changes to show latest values
        const mergedData = this.getMergedDataForEdit(relationshipType, id, data)
        console.log(`🔄 Merged data for modal:`, mergedData)

        // Build the edit URL
        const parentId = this.getParentEntityId()
        const editUrl = `/customers/${parentId}/${relationshipType}/${id}/edit`
        console.log(`📡 Loading form from: ${editUrl}`)

        // Load the form via turbo frame
        formFrame.src = editUrl

        // Show the modal using Bootstrap
        if (typeof bootstrap !== 'undefined') {
          const bootstrapModal = new bootstrap.Modal(modal)
          bootstrapModal.show()
          console.log(`✅ Modal shown via Bootstrap`)
        }

        // Store context for when modal is saved
        this.currentModalContext = {
          relationshipType,
          action: 'edit',
          id,
          data: mergedData
        }
        console.log(`✅ Modal context stored`)

        // Set up a listener for when the form loads to populate it with merged data
        formFrame.addEventListener('turbo:frame-load', () => {
          console.log(`📝 Form loaded, populating with merged data`)
          this.populateFormWithMergedData(formFrame, mergedData)
        }, { once: true })

      } else {
        console.log(`❌ No form frame found in modal`)
      }
    } else {
      console.log(`❌ No modal found with ID: ${modalId}`)
    }
  }

  getMergedDataForEdit(relationshipType, id, serverData) {
    // Start with server data as base
    const mergedData = { ...serverData }

    console.log(`🔍 getMergedDataForEdit called for ${relationshipType} ${id}:`, {
      serverData,
      changesExists: !!this.changes,
      hasRelationshipKey: !!(this.changes && this.changes[`${relationshipType}_attributes`])
    })

    // Check if there are pending changes for this record
    this.ensureKeyExists(`${relationshipType}_attributes`)
    const pendingChanges = this.changes[`${relationshipType}_attributes`]

    if (pendingChanges && pendingChanges[id]) {
      const pendingData = pendingChanges[id]

      // Merge pending changes over server data (pending takes priority)
      Object.keys(pendingData).forEach(key => {
        // Skip internal fields
        if (!['id', '_destroy', 'reason', 'reason_key'].includes(key)) {
          mergedData[key] = pendingData[key]
        }
      })

      console.log(`🔄 Found pending changes for ${relationshipType} ${id}:`, {
        serverData,
        pendingData,
        mergedData
      })
    } else {
      console.log(`📄 No pending changes found for ${relationshipType} ${id}, using server data only`)
    }

    return mergedData
  }

  getModalId(relationshipType) {
    // Convert plural relationship type to singular + EditModal
    let singularType = relationshipType

    // Handle common English pluralization patterns
    if (relationshipType.endsWith('ies')) {
      singularType = relationshipType.slice(0, -3) + 'y'
    } else if (relationshipType.endsWith('es')) {
      singularType = relationshipType.slice(0, -2)
    } else if (relationshipType.endsWith('s')) {
      singularType = relationshipType.slice(0, -1)
    }

    return `${singularType}EditModal`
  }

  getParentEntityId() {
    // Extract parent entity ID from URL or data attributes
    const currentPath = window.location.pathname
    const matches = currentPath.match(/\/customers\/(\d+)/)
    return matches ? matches[1] : null
  }

  populateFormWithMergedData(formFrame, mergedData) {
    console.log(`🔄 Populating form with merged data:`, mergedData)

    // Find the form inside the turbo frame
    const form = formFrame.querySelector('form')
    if (!form) {
      console.log(`❌ No form found in frame`)
      return
    }

    // Populate each field with merged data
    Object.keys(mergedData).forEach(key => {
      // Skip internal fields
      if (['id', '_destroy', 'reason', 'reason_key'].includes(key)) return

      // Find field by various name patterns
      const fieldSelectors = [
        `[name*="${key}"]`,
        `[name*="[${key}]"]`,
        `#address_${key}`,
        `#${key}`
      ]

      for (const selector of fieldSelectors) {
        const field = form.querySelector(selector)
        if (field) {
          if (field.type === 'checkbox') {
            field.checked = Boolean(mergedData[key])
          } else {
            field.value = mergedData[key] || ''
          }
          console.log(`✅ Set field ${key} = ${mergedData[key]}`)
          break
        }
      }
    })
  }

  // Handle modal save events
  handleModalSave(event) {
    const { modalId, formData } = event.detail

    if (!this.currentModalContext) return

    const { relationshipType, action, id } = this.currentModalContext

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
  handleModalCancel() {
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
    console.log('🔄 performUpdate called')

    // Get the reason from the modal
    const reasonInput = document.getElementById('modalAuditReason')
    if (!reasonInput) {
      console.error('❌ modalAuditReason input not found!')
      alert('Error: Reason input not found')
      return
    }

    const reason = reasonInput.value
    console.log('📝 Reason entered:', reason)

    if (!reason.trim()) {
      alert('Please provide a reason for the changes.')
      return
    }

    // Find the form
    const form = document.getElementById('customer_form')
    if (!form) {
      console.error('❌ Form with ID customer_form not found!')
      alert('Error: Form not found')
      return
    }
    console.log('✅ Form found:', form)

    // Set the reason in a hidden field (create one if needed since reasonInput is in modal)
    let reasonField = document.querySelector('input[name="customer[audit_reason]"]')
    if (!reasonField) {
      reasonField = document.createElement('input')
      reasonField.type = 'hidden'
      reasonField.name = 'customer[audit_reason]'
      form.appendChild(reasonField)
      console.log('✅ Created and added reason field to form')
    }
    reasonField.value = reason

    // Close the modal first
    const updateModal = document.getElementById('updateModal')
    if (updateModal) {
      try {
        // Use simple style hiding instead of Bootstrap modal hide
        updateModal.style.display = 'none'
        updateModal.classList.remove('show')
        document.body.classList.remove('modal-open')
        const backdrop = document.querySelector('.modal-backdrop')
        if (backdrop) backdrop.remove()
      } catch (e) {
        console.log('Modal hide error (ignoring):', e)
      }
    }

    // Disable Turbo for this form submission to ensure redirect works
    form.setAttribute('data-turbo', 'false')

    // Submit the form
    console.log('🚀 Submitting form...')
    form.submit()
  }
}