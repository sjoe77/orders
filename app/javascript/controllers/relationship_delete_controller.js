import { Controller } from "@hotwired/stimulus"

// Controller to handle the "Delete Selected" button functionality
export default class extends Controller {
  static values = {
    relationship: String,
    entity: String
  }

  connect() {
    this.element.addEventListener('click', this.deleteSelected.bind(this))
  }

  deleteSelected(event) {
    event.preventDefault()

    // Find all checked delete checkboxes in this relationship section
    const relationshipSection = this.element.closest('.relationship-section')
    if (!relationshipSection) return

    const checkedBoxes = relationshipSection.querySelectorAll('.delete-checkbox:checked')

    if (checkedBoxes.length === 0) {
      alert('Please select items to delete.')
      return
    }

    // Confirm deletion
    const entityName = this.entityValue
    const count = checkedBoxes.length
    const message = `Are you sure you want to delete ${count} ${entityName}${count > 1 ? 's' : ''}? This action cannot be undone.`

    if (!confirm(message)) {
      return
    }

    // Add the selected IDs to the pending changes for the graph form
    const graphFormController = document.querySelector('[data-controller="graph-form"]')
    if (graphFormController) {
      const graphFormStimulus = this.application.getControllerForElementAndIdentifier(graphFormController, 'graph-form')

      if (graphFormStimulus && graphFormStimulus.addRelationshipDeletes) {
        const selectedIds = Array.from(checkedBoxes).map(cb => cb.value)
        graphFormStimulus.addRelationshipDeletes(this.relationshipValue, selectedIds)

        // Clear the checkboxes and hide delete button
        checkedBoxes.forEach(cb => cb.checked = false)
        this.element.style.display = 'none'

        // Show success message
        alert(`${count} ${entityName}${count > 1 ? 's' : ''} marked for deletion. Save the form to apply changes.`)
      } else {
        console.error('Graph form controller not found or missing addRelationshipDeletes method')
      }
    }
  }
}