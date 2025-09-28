class ProductCategory < ApplicationRecord
  has_paper_trail meta: { audit_transaction_id: :paper_trail_audit_transaction_id }

  belongs_to :product
  belongs_to :category

  validates :product_id, uniqueness: { scope: :category_id }

  def paper_trail_audit_transaction_id
    PaperTrail.request.controller_info[:audit_transaction_id] if PaperTrail.request.controller_info
  end
end
