class HomeController < ApplicationController
  def index
  end

  def products
    render template: "home/template_page", locals: { 
      page_title: "Products", 
      page_description: "Manage your product catalog",
      icon: "package"
    }
  end

  def customers
    render template: "home/template_page", locals: { 
      page_title: "Customers", 
      page_description: "View and manage customer information",
      icon: "person"
    }
  end

  def orders
    render template: "home/template_page", locals: { 
      page_title: "Orders", 
      page_description: "Track and manage customer orders",
      icon: "list-ordered"
    }
  end

  def reports
    render template: "home/template_page", locals: { 
      page_title: "Reports", 
      page_description: "View analytics and generate reports",
      icon: "graph"
    }
  end

  def settings
    render template: "home/template_page", locals: { 
      page_title: "Settings", 
      page_description: "Configure application preferences",
      icon: "gear"
    }
  end
end
