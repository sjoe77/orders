import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "content", "themeToggle"]

  connect() {
    // Flag that Stimulus has connected
    window.stimulusConnected = true
    
    // Initialize drawer state from localStorage
    const storedState = localStorage.getItem('drawerOpen')
    this.isDrawerOpen = storedState === 'true'
    
    console.log('App shell controller connected - stored state:', storedState, 'isDrawerOpen:', this.isDrawerOpen)
    
    this.setupTheme()
    this.disableViewTransitions()
    this.setupKeyboardEvents()
    this.restoreDrawerState()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  toggleDrawer(event) {
    event.preventDefault()

    this.isDrawerOpen = !this.isDrawerOpen

    // Toggle the drawer-open class on the app shell
    if (this.isDrawerOpen) {
      this.element.classList.add('drawer-open')
      localStorage.setItem('drawerOpen', 'true')
    } else {
      this.element.classList.remove('drawer-open')
      localStorage.setItem('drawerOpen', 'false')
    }
  }

  navigateAndClose(event) {
    const link = event.currentTarget
    const currentPath = window.location.pathname
    const targetPath = new URL(link.href).pathname

    // If clicking the same page, prevent navigation
    if (currentPath === targetPath) {
      event.preventDefault()
      return
    }

    // Only close drawer on mobile - desktop drawer stays open
    if (this.isMobile() && this.isDrawerOpen) {
      this.isDrawerOpen = false
      this.element.classList.remove('drawer-open')
      localStorage.setItem('drawerOpen', 'false')
    }
  }

  restoreDrawerState() {
    // Apply the current state using CSS classes
    if (this.isDrawerOpen) {
      this.element.classList.add('drawer-open')
    } else {
      this.element.classList.remove('drawer-open')
    }
  }

  setupKeyboardEvents() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.isDrawerOpen) {
      this.isDrawerOpen = false
      this.element.classList.remove('drawer-open')
      localStorage.setItem('drawerOpen', 'false')
    }
  }

  isMobile() {
    return window.innerWidth < 1024
  }

  setupTheme() {
    // Get saved theme from localStorage or default to light
    this.currentTheme = localStorage.getItem('theme') || 'light'
    this.applyTheme(this.currentTheme)
  }

  toggleTheme(event) {
    event.preventDefault()
    this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light'
    this.applyTheme(this.currentTheme)
    localStorage.setItem('theme', this.currentTheme)
  }

  applyTheme(theme) {
    // Apply Bootstrap theme using data-bs-theme attribute
    document.documentElement.setAttribute('data-bs-theme', theme)

    // Update all theme toggle icons
    const themeButtons = document.querySelectorAll('[data-app-shell-target="themeToggle"] i, [data-action*="toggleTheme"] i')
    themeButtons.forEach(icon => {
      this.updateThemeIcon(icon, theme)
    })
  }

  updateThemeIcon(iconElement, theme) {
    // Remove existing Bootstrap icon classes
    iconElement.className = iconElement.className.replace(/bi-[\w-]+/g, '').trim()

    if (theme === 'dark') {
      iconElement.classList.add('bi', 'bi-moon-fill')
    } else {
      iconElement.classList.add('bi', 'bi-sun-fill')
    }
  }

  disableViewTransitions() {
    // Disable browser view transitions by intercepting the API
    if (document.startViewTransition) {
      const originalStartViewTransition = document.startViewTransition
      document.startViewTransition = function(callback) {
        // Just call the callback directly without starting a view transition
        if (callback) callback()
      }
    }
  }
}