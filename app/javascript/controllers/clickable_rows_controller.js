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
      // We're in a relationship table - dispatch event for modal
      const relationshipType = relationshipSection.dataset.relationshipType
      const relationshipPattern = relationshipSection.dataset.relationshipPattern

      // Get record data from the row
      const recordData = this.extractRecordData(row)

      // Find the parent graph-form controller element
      const graphFormElement = this.element.closest('[data-controller*="graph-form"]')
      if (graphFormElement) {
        // Dispatch the edit event to the graph form controller
        graphFormElement.dispatchEvent(new CustomEvent('relationship:action', {
          detail: {
            action: 'update',
            relationshipType: relationshipType,
            relationshipPattern: relationshipPattern,
            id: recordId,
            data: recordData
          },
          bubbles: true
        }))
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
}