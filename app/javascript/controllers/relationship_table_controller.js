import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["table"]

  // Dispatch events to the parent graph-form controller
  createRecord(event) {
    event.preventDefault()

    const relationshipSection = this.element.closest('[data-relationship-type]')
    if (!relationshipSection) {
      console.log('No relationship section found')
      return
    }

    const relationshipType = relationshipSection.dataset.relationshipType
    const relationshipPattern = relationshipSection.dataset.relationshipPattern

    console.log('Creating record:', { relationshipType, relationshipPattern })

    // Find the parent graph-form controller element
    const graphFormElement = this.element.closest('[data-controller*="graph-form"]')
    if (!graphFormElement) {
      console.log('No graph-form controller found')
      return
    }

    // Dispatch the event directly to the graph form controller element
    graphFormElement.dispatchEvent(new CustomEvent('relationship:action', {
      detail: {
        action: 'add',
        relationshipType: relationshipType,
        relationshipPattern: relationshipPattern,
        data: {}
      },
      bubbles: true
    }))
  }

  editRecord(event) {
    event.preventDefault()

    const button = event.currentTarget
    const recordId = button.dataset.recordId
    const recordData = JSON.parse(button.dataset.recordData || '{}')

    const relationshipSection = this.element.closest('[data-relationship-type]')
    if (!relationshipSection) return

    const relationshipType = relationshipSection.dataset.relationshipType
    const relationshipPattern = relationshipSection.dataset.relationshipPattern

    this.dispatch("relationship:action", {
      detail: {
        action: 'update',
        relationshipType: relationshipType,
        relationshipPattern: relationshipPattern,
        id: recordId,
        data: recordData
      },
      bubbles: true
    })
  }

  deleteRecord(event) {
    event.preventDefault()

    const button = event.currentTarget
    const recordId = button.dataset.recordId

    const relationshipSection = this.element.closest('[data-relationship-type]')
    if (!relationshipSection) return

    const relationshipType = relationshipSection.dataset.relationshipType
    const relationshipPattern = relationshipSection.dataset.relationshipPattern

    this.dispatch("relationship:action", {
      detail: {
        action: 'remove',
        relationshipType: relationshipType,
        relationshipPattern: relationshipPattern,
        id: recordId
      },
      bubbles: true
    })
  }

  viewRecord(event) {
    event.preventDefault()

    const button = event.currentTarget
    const recordId = button.dataset.recordId
    const recordData = JSON.parse(button.dataset.recordData || '{}')

    const relationshipSection = this.element.closest('[data-relationship-type]')
    if (!relationshipSection) return

    const relationshipType = relationshipSection.dataset.relationshipType

    // For view actions, we might want to navigate or show a modal
    // This is a placeholder - actual implementation depends on requirements
    console.log(`View ${relationshipType} record:`, recordId, recordData)
  }
}