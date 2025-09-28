import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // For nested attributes (like addresses), intercept form submission
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('submit', this.handleSubmit.bind(this))
  }

  handleSubmit(event) {
    // Check if this is a nested form (has pattern /entity/id/relationship)
    const isNestedForm = this.element.action.match(/\/\w+\/\d+\/\w+/)

    if (isNestedForm) {
      event.preventDefault() // Prevent normal submission

      // Extract form data
      const formData = new FormData(this.element)
      const formObject = {}
      for (let [key, value] of formData.entries()) {
        // Remove the model prefix (e.g., "address[city_nm]" becomes "city_nm")
        const fieldName = key.includes('[') ? key.split('[')[1].replace(']', '') : key
        formObject[fieldName] = value
      }

      // Get the address ID from form or URL
      const addressId = formObject.id || this.extractAddressId()

      // Find the graph-form controller
      const graphForm = document.querySelector('[data-controller*="graph-form"]')
      if (graphForm) {
        const controller = this.application.getControllerForElementAndIdentifier(graphForm, 'graph-form')
        if (controller) {
          if (addressId && addressId !== '') {
            // Update existing address
            console.log('🔧 Modal form submitting UPDATE for address:', addressId, formObject)
            controller.performUpdateNestedAttribute('addresses', addressId, formObject)
          } else {
            // Create new address
            console.log('🔧 Modal form submitting CREATE for address:', formObject)
            controller.createNestedAttribute('addresses', formObject)
          }
        }
      }

      // Close the modal
      this.closeModal()
    }
    // For non-nested forms, let them submit normally
  }

  extractAddressId() {
    // Try to get address ID from the form action URL
    const match = this.element.action.match(/addresses\/(\d+)/)
    return match ? match[1] : null
  }

  closeModal() {
    const modal = this.element.closest('.modal')
    if (modal) {
      const bootstrapModal = bootstrap.Modal.getInstance(modal)
      if (bootstrapModal) {
        bootstrapModal.hide()
      }
    }
  }
}