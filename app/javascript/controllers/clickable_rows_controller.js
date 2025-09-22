import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  rowClicked(event) {
    // Don't trigger if clicking on buttons or links
    if (event.target.closest('a, button')) {
      return
    }

    const row = event.currentTarget
    // Try different data attributes for record ID
    const recordId = row.dataset.recordId || row.dataset.customerId

    // Check if we're in a relationship context (inside a relationship-section)
    const relationshipSection = this.element.closest('[data-relationship-type]')

    if (relationshipSection) {
      // We're in a relationship table - open edit modal
      const relationshipType = relationshipSection.dataset.relationshipType
      // Proper singularization - handle common English plural patterns
      let entityName = relationshipType
      if (relationshipType.endsWith('ies')) {
        entityName = relationshipType.slice(0, -3) + 'y'
      } else if (relationshipType.endsWith('es')) {
        entityName = relationshipType.slice(0, -2)
      } else if (relationshipType.endsWith('s')) {
        entityName = relationshipType.slice(0, -1)
      }

      // Load the edit form into the modal
      const editModalId = `${entityName}EditModal`
      const editModal = document.getElementById(editModalId)

      if (editModal && recordId) {
        console.log(`🔍 Looking for graph-form controller for ${relationshipType} ${recordId}`)

        // Find the graph-form controller to handle data merging
        const graphForm = document.querySelector('[data-controller*="graph-form"]')
        console.log(`🔍 Found graph-form element:`, graphForm)

        if (graphForm) {
          const controller = this.application.getControllerForElementAndIdentifier(graphForm, 'graph-form')
          console.log(`🔍 Found graph-form controller:`, controller)

          if (controller) {
            // Extract the record data from the row for merging
            const recordData = this.extractRecordDataFromRow(row)

            console.log(`🎯 Clickable row calling showEditModal for ${relationshipType} ${recordId}:`, recordData)

            // Call the graph-form controller's method that handles data merging
            controller.showEditModal(relationshipType, recordId, recordData)
            return // Exit early to prevent fallback
          } else {
            console.log(`❌ Could not get graph-form controller instance`)
          }
        } else {
          console.log(`❌ No graph-form element found on page`)
        }

        // Fallback to direct form loading if no graph-form controller
        console.log(`🔄 Falling back to direct form loading`)
        const formFrame = editModal.querySelector('turbo-frame[id$="_form"]')
        if (formFrame) {
          // Build edit URL based on parent entity
          const parentId = this.getParentEntityId()
          const editUrl = `/customers/${parentId}/${relationshipType}/${recordId}/edit`

          console.log(`📡 Loading form from: ${editUrl}`)

          // Set the source to load the form
          formFrame.src = editUrl

          // Show the modal
          if (typeof bootstrap !== 'undefined') {
            const bootstrapModal = new bootstrap.Modal(editModal)
            bootstrapModal.show()
          }
        }
      }
    } else {
      // We're in the main table - navigate to full edit page
      // Determine the model type from the record class or make a reasonable assumption
      if (recordId) {
        // For now, assume this is a customer table (can be made more generic later)
        window.location.href = `/customers/${recordId}/edit`
      }
    }
  }

  extractRecordData(row) {
    // Generic data extraction - just pass the record ID
    // The actual record data will be fetched when needed
    return {
      id: row.dataset.recordId || row.dataset.customerId
    }
  }

  extractRecordDataFromRow(row) {
    // Extract all data attributes and cell values from the table row
    const recordData = {}

    // Get record ID from data attributes
    recordData.id = row.dataset.recordId || row.dataset.customerId

    // Extract data from the row's cells - this is basic extraction
    // In a more sophisticated version, we could map table headers to field names
    const cells = row.querySelectorAll('td')
    const tableHeaders = row.closest('table').querySelector('thead tr')

    if (tableHeaders) {
      const headers = Array.from(tableHeaders.querySelectorAll('th'))
      headers.forEach((header, index) => {
        if (cells[index]) {
          const fieldName = header.dataset.field || header.textContent.trim().toLowerCase().replace(/\s+/g, '_')
          recordData[fieldName] = cells[index].textContent.trim()
        }
      })
    }

    return recordData
  }

  getParentEntityId() {
    // Extract parent entity ID from URL or data attributes
    const currentPath = window.location.pathname
    const matches = currentPath.match(/\/customers\/(\d+)/)
    return matches ? matches[1] : null
  }
}