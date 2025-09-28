import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "itemsList", "itemCheckbox", "selectedCount", "saveButton"]
  static values = {
    relationshipType: String,
    linkActionPath: String,
    frameId: String
  }

  connect() {
    console.log('🎯 Many-to-Many Controller connected!')
    console.log('🎯 Element:', this.element)
    console.log('🎯 Available targets:', this.targets)
    console.log('🎯 Values:', {
      relationshipType: this.relationshipTypeValue,
      linkActionPath: this.linkActionPathValue,
      frameId: this.frameIdValue
    })

    this.attachSearchListener()

    // Set up mutation observer to watch for Turbo Frame content loading
    this.setupTurboFrameObserver()

    // Also try immediate setup in case content is already loaded
    setTimeout(() => {
      this.setupCheckboxListeners()
      this.updateSelectedCount()
    }, 100)
  }

  disconnect() {
    if (this.frameObserver) {
      this.frameObserver.disconnect()
    }
  }

  attachSearchListener() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.addEventListener('input', this.debounce(this.filterItems.bind(this), 300))
    }
  }

  filterItems() {
    const searchTerm = this.searchInputTarget.value.toLowerCase()
    const items = this.itemsListTarget.querySelectorAll('.form-check')

    items.forEach(item => {
      const label = item.querySelector('label')
      const text = label.textContent.toLowerCase()

      if (text.includes(searchTerm)) {
        item.style.display = 'block'
      } else {
        item.style.display = 'none'
      }
    })
  }

  selectAll() {
    const visibleCheckboxes = this.getVisibleCheckboxes()
    visibleCheckboxes.forEach(checkbox => {
      checkbox.checked = true
    })
    this.updateSelectedCount()
  }

  clearAll() {
    const visibleCheckboxes = this.getVisibleCheckboxes()
    visibleCheckboxes.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateSelectedCount()
  }

  getVisibleCheckboxes() {
    return this.itemCheckboxTargets.filter(checkbox => {
      const formCheck = checkbox.closest('.form-check')
      return formCheck && formCheck.style.display !== 'none'
    })
  }

  updateSelectedCount() {
    console.log('🔢 updateSelectedCount called')
    console.log('🔢 itemCheckboxTargets length:', this.itemCheckboxTargets.length)

    const selectedCount = this.itemCheckboxTargets.filter(checkbox => checkbox.checked).length
    console.log('🔢 Selected count:', selectedCount)

    if (this.hasSelectedCountTarget) {
      console.log('🔢 Updating selectedCount target to:', selectedCount)
      this.selectedCountTarget.textContent = selectedCount
    } else {
      console.log('❌ No selectedCount target found')
    }
  }

  itemCheckboxTargetConnected(element) {
    element.addEventListener('change', this.updateSelectedCount.bind(this))
  }

  setupTurboFrameObserver() {
    // Watch for changes in the modal body (when Turbo Frame loads)
    this.frameObserver = new MutationObserver((mutations) => {
      // Only react to meaningful changes (avoid infinite loops)
      const hasCheckboxes = mutations.some(mutation => {
        for (let node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            // Check if this added node contains checkboxes
            return node.querySelector && (
              node.querySelector('[data-many-to-many-target="itemCheckbox"]') ||
              node.matches('[data-many-to-many-target="itemCheckbox"]')
            )
          }
        }
        return false
      })

      if (hasCheckboxes) {
        console.log('🔄 Turbo Frame loaded with checkboxes, setting up listeners')
        this.setupCheckboxListeners()
        this.updateSelectedCount()
      }
    })

    this.frameObserver.observe(this.element, {
      childList: true,
      subtree: true
    })
  }

  setupCheckboxListeners() {
    console.log('🎧 Setting up checkbox listeners')
    // Use event delegation on the container to handle dynamically loaded checkboxes
    const itemsList = this.hasItemsListTarget ? this.itemsListTarget : null
    console.log('🎧 itemsList found:', !!itemsList)

    if (itemsList) {
      // Remove existing listener to avoid duplicates
      itemsList.removeEventListener('change', this.boundCheckboxChange)
      // Add new delegated listener
      itemsList.addEventListener('change', this.boundCheckboxChange)
      console.log('🎧 Event listener added to itemsList')
    } else {
      console.log('❌ No itemsList target found')
    }

    // Also set up initial state for pre-checked items
    this.updateSelectedCount()
  }

  get boundCheckboxChange() {
    if (!this._boundCheckboxChange) {
      this._boundCheckboxChange = (event) => {
        if (event.target.matches('[data-many-to-many-target="itemCheckbox"]')) {
          this.updateSelectedCount()
        }
      }
    }
    return this._boundCheckboxChange
  }

  get boundUpdateCount() {
    if (!this._boundUpdateCount) {
      this._boundUpdateCount = this.updateSelectedCount.bind(this)
    }
    return this._boundUpdateCount
  }

  saveChanges() {
    const selectedIds = this.itemCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)

    const relationshipType = this.relationshipTypeValue
    console.log('🔄 Save Changes - Selected IDs:', selectedIds)
    console.log('🔄 Save Changes - Relationship Type:', relationshipType)

    // Store changes in pending_changes field for later processing
    this.storePendingChanges(relationshipType, selectedIds)

    // Update inline relationship table immediately (client-side patch replay)
    this.updateInlineRelationshipTable(selectedIds)

    // Close modal
    const modal = bootstrap.Modal.getInstance(this.element.closest('.modal'))
    if (modal) {
      modal.hide()
    }
  }

  storePendingChanges(relationshipType, selectedIds) {
    // Find the main form and its pending_changes field
    const mainForm = document.querySelector('[data-controller*="graph-form"]')
    if (!mainForm) {
      console.error('Could not find main form with graph-form controller')
      return
    }

    const pendingChangesField = mainForm.querySelector('[data-graph-form-target="pendingChanges"]')
    if (!pendingChangesField) {
      console.error('Could not find pending changes field')
      return
    }

    // Get existing pending changes
    let pendingChanges = {}
    try {
      if (pendingChangesField.value) {
        pendingChanges = JSON.parse(pendingChangesField.value)
      }
    } catch (e) {
      console.warn('Could not parse existing pending changes:', e)
      pendingChanges = {}
    }

    // Store M:M relationship changes
    pendingChanges[`${relationshipType}_ids`] = selectedIds

    // Update the field
    pendingChangesField.value = JSON.stringify(pendingChanges)

    // Trigger change event for graph-form controller
    pendingChangesField.dispatchEvent(new Event('input', { bubbles: true }))
  }

  updateInlineRelationshipTable(selectedIds) {
    // Find the inline relationship table in the main form
    const frameId = this.frameIdValue
    console.log('🔄 Looking for frame ID:', frameId)
    const relationshipFrame = document.getElementById(frameId)

    if (!relationshipFrame) {
      console.warn('❌ Could not find relationship frame with ID:', frameId)
      return
    }
    console.log('✅ Found relationship frame:', relationshipFrame)

    // Get selected items data from the modal checkboxes
    const selectedItemsData = this.getSelectedItemsData(selectedIds)
    console.log('🔄 Selected items data:', selectedItemsData)

    // Update the relationship table with selected items
    this.replaceRelationshipTableContent(relationshipFrame, selectedItemsData)
    console.log('✅ Updated relationship table content')
  }

  getSelectedItemsData(selectedIds) {
    const itemsData = []

    selectedIds.forEach(id => {
      // Find the checkbox and its associated data from the modal
      const checkbox = this.itemCheckboxTargets.find(cb => cb.value === id)
      if (checkbox) {
        const row = checkbox.closest('tr')
        if (row) {
          // Extract item data from the table row (generic approach)
          const cells = row.querySelectorAll('td')
          if (cells.length >= 2) { // At least checkbox column + 1 data column
            const itemData = { id: id }

            // Extract data from each cell (skip first checkbox column)
            for (let i = 1; i < cells.length; i++) {
              const cell = cells[i]
              const cellText = cell.textContent?.trim() || ''

              // Try to determine what type of data this is
              if (i === 1) itemData.name = cellText
              else if (i === 2) itemData.description = cellText
              else if (i === 3) itemData.displayOrder = cellText
              else if (cell.querySelector('i')) {
                // Boolean field with icon
                itemData.active = cell.querySelector('i')?.classList.contains('text-success') || false
              }
            }

            itemsData.push(itemData)
          }
        }
      }
    })

    return itemsData
  }

  replaceRelationshipTableContent(relationshipFrame, itemsData) {
    // Find the relationship section within the frame
    const relationshipSection = relationshipFrame.querySelector('.relationship-section')
    if (!relationshipSection) {
      console.warn('Could not find relationship section')
      return
    }

    // Update the header count
    const headerTitle = relationshipSection.querySelector('h6')
    if (headerTitle) {
      const relationshipType = this.relationshipTypeValue
      headerTitle.textContent = `${relationshipType.charAt(0).toUpperCase() + relationshipType.slice(1)} (${itemsData.length})`
    }

    // Find the table container
    const tableContainer = relationshipSection.querySelector('.table-container')
    if (!tableContainer) {
      console.warn('Could not find table container')
      return
    }

    if (itemsData.length === 0) {
      // Show empty state
      tableContainer.innerHTML = `
        <div class="text-center py-4 text-muted">
          <i class="bi bi-link-45deg fs-1 mb-2 d-block"></i>
          <p class="mb-0">No ${this.relationshipTypeValue.toLowerCase()} linked yet</p>
          <small>Click "Manage ${this.relationshipTypeValue.charAt(0).toUpperCase() + this.relationshipTypeValue.slice(1)}" to add relationships</small>
        </div>
      `
    } else {
      // Build the table with selected items
      tableContainer.innerHTML = this.buildRelationshipTableHTML(itemsData)
    }

    // Remove any existing pending notices to avoid accumulation
    const existingNotices = relationshipSection.querySelectorAll('.alert-info')
    existingNotices.forEach(notice => notice.remove())
  }

  buildRelationshipTableHTML(itemsData) {
    if (itemsData.length === 0) return ''

    // For categories, build the specific table structure
    const relationshipType = this.relationshipTypeValue

    if (relationshipType === 'categories') {
      return `
        <div class="table-responsive">
          <table class="table table-striped table-hover">
            <thead class="table-secondary">
              <tr>
                <th class="text-start">Category Name</th>
                <th class="text-start">Description</th>
                <th class="text-end">Display Order</th>
                <th class="text-center">Active</th>
              </tr>
            </thead>
            <tbody>
              ${itemsData.map(item => `
                <tr>
                  <td class="text-start">${this.escapeHtml(item.name)}</td>
                  <td class="text-start">${this.escapeHtml(item.description)}</td>
                  <td class="text-end">${this.escapeHtml(item.displayOrder)}</td>
                  <td class="text-center">
                    <i class="bi-check-circle-fill ${item.active ? 'text-success' : 'text-danger'}" title="${item.active ? 'Yes' : 'No'}"></i>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      `
    }

    // Generic fallback for other relationship types
    return `
      <div class="table-responsive">
        <table class="table table-striped table-hover">
          <thead class="table-secondary">
            <tr>
              <th class="text-start">Name</th>
              <th class="text-start">Description</th>
            </tr>
          </thead>
          <tbody>
            ${itemsData.map(item => `
              <tr>
                <td class="text-start">${this.escapeHtml(item.name)}</td>
                <td class="text-start">${this.escapeHtml(item.description)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Keep the direct save method for immediate saves (optional)
  saveChangesDirectly() {
    const selectedIds = this.itemCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)

    const linkActionPath = this.linkActionPathValue
    const relationshipType = this.relationshipTypeValue

    if (!linkActionPath) {
      console.error('No link action path specified')
      return
    }

    this.saveButtonTarget.disabled = true
    this.saveButtonTarget.innerHTML = '<span class="spinner-border spinner-border-sm me-2" role="status"></span>Saving...'

    const formData = new FormData()
    formData.append('authenticity_token', this.getCSRFToken())
    formData.append('selected_ids', JSON.stringify(selectedIds))
    formData.append('relationship_type', relationshipType)

    fetch(linkActionPath, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Close modal
        const modal = bootstrap.Modal.getInstance(this.element.closest('.modal'))
        if (modal) {
          modal.hide()
        }

        // Refresh the current items display via Turbo Frame
        const frameId = this.frameIdValue
        if (frameId) {
          const frame = document.getElementById(frameId)
          if (frame) {
            frame.src = frame.src
          }
        }

        // Show success message
        this.showNotification('Relationships updated successfully', 'success')
      } else {
        this.showNotification(data.error || 'Failed to update relationships', 'error')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showNotification('An error occurred while updating relationships', 'error')
    })
    .finally(() => {
      this.saveButtonTarget.disabled = false
      this.saveButtonTarget.innerHTML = 'Save Changes'
    })
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  showNotification(message, type) {
    // Create a simple toast notification
    const toast = document.createElement('div')
    toast.className = `alert alert-${type === 'success' ? 'success' : 'danger'} position-fixed`
    toast.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;'
    toast.innerHTML = `
      <div class="d-flex align-items-center">
        <i class="bi bi-${type === 'success' ? 'check-circle' : 'exclamation-triangle'} me-2"></i>
        ${message}
        <button type="button" class="btn-close ms-auto" data-bs-dismiss="alert"></button>
      </div>
    `

    document.body.appendChild(toast)

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
    }, 5000)
  }

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }
}