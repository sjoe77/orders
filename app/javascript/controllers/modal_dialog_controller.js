import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]
  static values = {
    modalId: String,
    saveCallback: String,
    cancelCallback: String
  }

  connect() {
    this.modal = new bootstrap.Modal(this.element)
    this.setupEventListeners()
  }

  disconnect() {
    if (this.modal) {
      this.modal.dispose()
    }
  }

  // Show the modal
  show() {
    this.modal.show()
  }

  // Hide the modal
  hide() {
    this.modal.hide()
  }

  // Save button clicked
  save(event) {
    event.preventDefault()

    if (this.hasFormTarget) {
      // Validate form if it exists
      const form = this.formTarget
      if (!form.checkValidity()) {
        form.classList.add('was-validated')
        return
      }

      // Dispatch save event with form data
      this.dispatch("save", {
        detail: {
          modalId: this.modalIdValue,
          formData: new FormData(form),
          form: form
        }
      })
    } else {
      // No form, just dispatch save event
      this.dispatch("save", {
        detail: {
          modalId: this.modalIdValue
        }
      })
    }
  }

  // Cancel button clicked or modal dismissed
  cancel(event) {
    event?.preventDefault()

    this.dispatch("cancel", {
      detail: {
        modalId: this.modalIdValue
      }
    })

    this.hide()
  }

  // Handle modal events
  setupEventListeners() {
    this.element.addEventListener('hidden.bs.modal', () => {
      this.dispatch("closed", {
        detail: {
          modalId: this.modalIdValue
        }
      })
    })

    this.element.addEventListener('shown.bs.modal', () => {
      this.dispatch("opened", {
        detail: {
          modalId: this.modalIdValue
        }
      })

      // Focus first input when modal opens
      const firstInput = this.element.querySelector('input:not([type="hidden"]), select, textarea')
      if (firstInput) {
        firstInput.focus()
      }
    })
  }

  // Helper method to populate form with data
  populateForm(data) {
    if (!this.hasFormTarget) return

    const form = this.formTarget
    Object.keys(data).forEach(key => {
      const field = form.querySelector(`[name*="${key}"]`)
      if (field) {
        if (field.type === 'checkbox') {
          field.checked = Boolean(data[key])
        } else {
          field.value = data[key] || ''
        }
      }
    })
  }

  // Helper method to clear form
  clearForm() {
    if (!this.hasFormTarget) return

    const form = this.formTarget
    form.reset()
    form.classList.remove('was-validated')
  }
}