module ApplicationHelper
  # Helper methods for Beer CSS Material Design
  def material_icon(name, **options)
    content_tag :i, name, **options
  end
end
