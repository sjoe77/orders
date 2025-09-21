import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { customerId: String }

  loadAddresses(event) {
    // The Turbo Frame will handle the loading automatically
    // This method can be used for additional logic if needed
    console.log("Loading addresses for customer", this.customerIdValue)
  }

  loadOrders(event) {
    // The Turbo Frame will handle the loading automatically
    // This method can be used for additional logic if needed
    console.log("Loading orders for customer", this.customerIdValue)
  }
}